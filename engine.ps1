# Autor: LetsBash.de / SirBash.com

function retriveLatestSavegame {
    param(
        [string]$gametypes = "Multiplayer,SinglePlayer,MultiplayerClient"
    )
    $lastestpath = $false
    $lastesttime = $false
    $savepath = ($ENV:LOCALAPPDATA + "low\Endnight\SonsOfTheForest\Saves\")
    $steamidfolders = Get-ChildItem -path $savepath
    foreach ($steamidfolder in $steamidfolders) {
        foreach ($gametype in ($gametypes -split ',')) {
            $savegamepath = ($steamidfolder.fullname + "\" + $gametype)
            if (!(test-path -Path $savegamepath)) {
                continue
            }
            $savegamefolders = Get-ChildItem -path $savegamepath
            foreach ($savegamefolder in $savegamefolders) {
                $filepath = ($savegamefolder.fullname + "\SaveData.json")
                $savegame = get-item -path $filepath
                $modifiedtime = $savegame.LastWriteTime
    
                if ($lastesttime -eq $false) {
                    $lastesttime = $modifiedtime
                    $lastestpath = $savegamefolder.fullname
                }
    
                if ($modifiedtime -gt $lastesttime) {
                    $lastesttime = $modifiedtime
                    $lastestpath = $savegamefolder.fullname
                }
            }
        }
    }
    return $lastestpath
}

function reviveNPCs {
    param(
        [string]$lastestpath
    )

    # Sanatize
    if ($lastestpath -eq $false) {
        write-host "There are not savegames avalible" -ForegroundColor White -BackgroundColor Red
        return $false
    }

    # Create savegamefilepaths
    $GameStateSaveDataPath = ($lastestpath + "\GameStateSaveData.json")
    $SaveDataPath = ($lastestpath + "\SaveData.json")

    # Testing files
    if (!(test-path -path $GameStateSaveDataPath)) {
        write-host ($GameStateSaveDataPath + " is missing") -ForegroundColor White -BackgroundColor Red
        return $false
    }
    if (!(test-path -path $SaveDataPath)) {
        write-host ($SaveDataPath + " is missing") -ForegroundColor White -BackgroundColor Red
        return $false
    }

    # Stage 1 - GameStateSaveData.json
    $content = getSavegame $GameStateSaveDataPath
    $change = $false
    
    if ($content -eq $false) {
        write-host ($GameStateSaveDataPath + " has no data") -ForegroundColor White -BackgroundColor Red
        return $false
    }

    if ($content -like '*\"IsRobbyDead\":true,*') {
        $change = $true
        $content = $content -replace '[\\]["]IsRobbyDead[\\]["][:]true,', '\"IsRobbyDead\":false,'
    }

    if ($content -like '*\"IsVirginiaDead\":true,*') {
        $change = $true
        $content = $content -replace ('[\\]["]IsVirginiaDead[\\]["][:]true,'), '\"IsVirginiaDead\":false,'
    }

    if ($change -eq $true) {
        if (writeSavegame $GameStateSaveDataPath $content) {
            write-host ($GameStateSaveDataPath + " savegame modified") -ForegroundColor green -BackgroundColor Black
        }
        else {
            write-host ($GameStateSaveDataPath + " could not write to savegame") -ForegroundColor yellow -BackgroundColor Black
            return $false
        }
    }
    else {
        write-host ($SaveDataPath + " savegame does not need modification") -ForegroundColor yellow -BackgroundColor Black
        #return $false
    }

    # Stage 2 - SaveData.json
    $content = getSavegame $SaveDataPath
    $original = $content 

    if ($content -eq $false) {
        write-host ($SaveDataPath + " has no data") -ForegroundColor White -BackgroundColor Red
        return $false
    }

    if ($content -like '*,\"TypeId\":9,*') {
        $NPCpattern = '[{][\\]["]UniqueId[\\]["][:][0-9]*[,][\\]["]TypeId[\\]["][:]9[,][^\}]*[}][^\}]*[}][^\}]*[}][,][\\]["]StateFlags[\\]["][:][0-9]{1,4}[}]';
        $NPCs = [regex]::Matches($content, $NPCpattern)
        foreach($oldNPC in $NPCs)
        {
            $newNPC = $oldNPC -replace '[\\]["]State[\\]["]:[0-9]{1,2}[,]','\"State\":2,'
            $newNPC = $newNPC -replace '[\\]["]Stats[\\]["]:[{][^}]*[}],','\"Stats\":{\"Health\":999,\"Anger\":60.25404,\"Fear\":99.97499,\"Fullness\":6.249775,\"Hydration\":0.0,\"Energy\":90.5,\"Affection\":0.0},'
            $content = $content -replace [regex]::escape($oldNPC), $newNPC
        }
        write-host ($SaveDataPath + " type id 9 (Kelvin) is modified") -ForegroundColor green -BackgroundColor Black
    }

    if ($content -like '*,\"TypeId\":10,*') {
        $NPCpattern = '[{][\\]["]UniqueId[\\]["][:][0-9]*[,][\\]["]TypeId[\\]["][:]10[,][^\}]*[}][^\}]*[}][^\}]*[}][,][\\]["]StateFlags[\\]["][:][0-9]{1,4}[}]';
        $NPCs = [regex]::Matches($content, $NPCpattern)
        foreach($oldNPC in $NPCs)
        {
            $newNPC = $oldNPC -replace '[\\]["]State[\\]["]:[0-9]{1,2}[,]','\"State\":2,'
            $newNPC = $newNPC -replace '[\\]["]Stats[\\]["]:[{][^}]*[}],','\"Stats\":{\"Health\":999.0,\"Anger\":0.0,\"Fear\":0.0,\"Fullness\":0.0,\"Hydration\":0.0,\"Energy\":90.5,\"Affection\":100.0},'
            $content = $content -replace [regex]::escape($oldNPC), $newNPC
        }
        write-host ($SaveDataPath + " type id 10 (Virginia) is modified") -ForegroundColor green -BackgroundColor Black
    }

    if ($content -like '*,{\"TypeId\":9,\"PlayerKilled\":*') {
        $content = $content -replace '[{][\\]["]TypeId[\\]["][:]9[,][\\]["]PlayerKilled[\\]["][:][0-9]*[}]', '{\"TypeId\":9,\"PlayerKilled\":0}'
        write-host ($SaveDataPath + " type id 9 (Kelvin) kill counter reset") -ForegroundColor green -BackgroundColor Black
    }

    if ($content -like '*,{\"TypeId\":10,\"PlayerKilled\":*') {
        $content = $content -replace '[{][\\]["]TypeId[\\]["][:]10[,][\\]["]PlayerKilled[\\]["][:][0-9]*[}]', '{\"TypeId\":10,\"PlayerKilled\":0}'
        write-host ($SaveDataPath + " type id 10 (Virginia) kill counter reset") -ForegroundColor green -BackgroundColor Black
    }

    if ($original -ne $content) {
        if (writeSavegame $SaveDataPath $content) {
            write-host ($SaveDataPath + " savegame modified") -ForegroundColor green -BackgroundColor Black
        }
        else {
            write-host ($SaveDataPath + " could not write to savegame") -ForegroundColor yellow -BackgroundColor Black
            return $false
        }
    }
    else {
        write-host ($SaveDataPath + " savegame does not need modification") -ForegroundColor yellow -BackgroundColor Black
        return $false
    }

    return $true

    # Sample Code from a savegame
    #
    # GameStateSaveData.json
    # \"IsRobbyDead\":true,
    # \"IsVirginiaDead\":false,
    #
    # SaveData.json - Kelvin
    # {\"UniqueId\":711,\"TypeId\":9,\"FamilyId\":0,\"Position\":{\"x\":-1236.10144,\"y\":99.1763458,\"z\":1396.66663},\"Rotation\":{\"x\":0.0,\"y\":-0.15448457,\"z\":0.0,\"w\":-0.9879952},\"SpawnerId\":0,\"ActorSeed\":-1228319904,\"VariationId\":0,\"State\":6,\"GraphMask\":1,\"EquippedItems\":[504],\"OutfitId\":-1,\"NextGiftTime\":0.0,\"LastVisitTime\":-100.0,\"Stats\":{\"Health\":100,\"Anger\":60.25404,\"Fear\":99.97499,\"Fullness\":6.249775,\"Hydration\":0.0,\"Energy\":90.5,\"Affection\":0.0},\"StateFlags\":0}
    # {\"TypeId\":9,\"PlayerKilled\":1}
    #
    # SaveData.json - Virginia
    # {\"UniqueId\":709,\"TypeId\":10,\"FamilyId\":0,\"Position\":{\"x\":-543.530334,\"y\":125.27742,\"z\":419.568665},\"Rotation\":{\"x\":0.0,\"y\":0.990344,\"z\":0.0,\"w\":0.1386319},\"SpawnerId\":-1797797444,\"ActorSeed\":787901937,\"VariationId\":0,\"State\":2,\"GraphMask\":1,\"EquippedItems\":null,\"OutfitId\":-1,\"NextGiftTime\":0.0,\"LastVisitTime\":-100.0,\"Stats\":{\"Health\":120.0,\"Anger\":0.0,\"Fear\":0.0,\"Fullness\":0.0,\"Hydration\":0.0,\"Energy\":90.5,\"Affection\":0.0},\"StateFlags\":0}
    # {\"TypeId\":10,\"PlayerKilled\":0}

}

function copyNPCs {
    param(
        [string]$lastestpath
    )

    # Sanatize
    if ($lastestpath -eq $false) {
        write-host "There are not savegames avalible" -ForegroundColor White -BackgroundColor Red
        return $false
    }

    # Create savegamefilepaths
    $GameStateSaveDataPath = ($lastestpath + "\GameStateSaveData.json")
    $SaveDataPath = ($lastestpath + "\SaveData.json")

    # Testing files
    if (!(test-path -path $GameStateSaveDataPath)) {
        write-host ($GameStateSaveDataPath + " is missing") -ForegroundColor White -BackgroundColor Red
        return $false
    }
    if (!(test-path -path $SaveDataPath)) {
        write-host ($SaveDataPath + " is missing") -ForegroundColor White -BackgroundColor Red
        return $false
    }

    # Stage 1 - GameStateSaveData.json
    $content = getSavegame $GameStateSaveDataPath
    $change = $false
    
    if ($content -eq $false) {
        write-host ($GameStateSaveDataPath + " has no data") -ForegroundColor White -BackgroundColor Red
        return $false
    }

    if ($content -like '*\"IsRobbyDead\":true,*') {
        $change = $true
        $content = $content -replace '[\\]["]IsRobbyDead[\\]["][:]true,', '\"IsRobbyDead\":false,'
    }

    if ($content -like '*\"IsVirginiaDead\":true,*') {
        $change = $true
        $content = $content -replace ('[\\]["]IsVirginiaDead[\\]["][:]true,'), '\"IsVirginiaDead\":false,'
    }

    if ($change -eq $true) {
        if (writeSavegame $GameStateSaveDataPath $content) {
            write-host ($GameStateSaveDataPath + " savegame modified") -ForegroundColor green -BackgroundColor Black
        }
        else {
            write-host ($GameStateSaveDataPath + " could not write to savegame") -ForegroundColor yellow -BackgroundColor Black
            return $false
        }
    }
    else {
        write-host ($SaveDataPath + " savegame does not need modification") -ForegroundColor yellow -BackgroundColor Black
    }

    # Stage 2 - SaveData.json
    $content = getSavegame $SaveDataPath

    if ($content -eq $false) {
        write-host ($SaveDataPath + " has no data") -ForegroundColor White -BackgroundColor Red
        return $false
    }

    # Enumerate max UniqueId
    $maxUniqueId = 0
    $fragments = $content -split '[\\]["]UniqueId[\\]["][:]'
    $skipfirst = $false;
    foreach($fragment in $fragments)
    {
        if($skipfirst -eq $false)
        {
            $skipfirst = $true
            continue
        }
        if($fragment -notmatch '[0-9].*')
        {
            continue
        }

        $value = [int]($fragment -split '[^0-9]')[0]
        if($maxUniqueId -lt $value)
        {
            $maxUniqueId = $value
        }
    }
    
    # Get amount of NPC to insert
    $virginias = -1
    while ($virginias -lt 0 -or $location -gt 999)
    {
        write-host ""
        write-host "Just for information: I could spawn only 5 Virginias additional in my savegames"
        $virginias = read-host -Prompt "How many Virginias you want to spawn (0-999)"
    }
    write-host ("vSpawn set to "+$virginias)

    $kelvins = -1
    while ($kelvins -lt 0 -or $kelvins -gt 999)
    {
        write-host ""
        write-host "Just for information: Kelvin looks like not having a limit at all :)"
        $kelvins = read-host -Prompt "How many Kelvins you want to spawn (0-999)"
    }
    write-host ("kSpawn set to "+$kelvins)

    $location = 0
    while($location -lt 1 -or $location -gt 2)
    {
        write-host ""
        write-host "Select a common game start spawn"
        write-host "1: At the strand"
        write-host "2: In the forest"
        write-host "snow is currently not implemented."
        $location = read-host -Prompt "Where do you want to spawn your new friends?"
    }
    write-host ("Location set to "+$location)

    # Define final coordinates
    $postion = '{\"x\":-1148.47742,\"y\":138.830429,\"z\":-225.7233}'   # forest
    if($location -eq 1)
    {
        $postion = '{\"x\":-415.6325,\"y\":14.3780384,\"z\":1596.5188}'     # strand
    }

    # Insert Virginia
    write-host "Process Virginia" -NoNewline
    for ($i = 0; $i -lt $virginias; $i++)
    {
        $maxUniqueId++
        $find = '[\\]["]Actors[\\]["][:][\[]'
        $replace = '\"Actors\":[{\"UniqueId\":'+$maxUniqueId+',\"TypeId\":10,\"FamilyId\":0,\"Position\":'+$postion+',\"Rotation\":{\"x\":0.0,\"y\":-0.9923399,\"z\":0.0,\"w\":0.123537354},\"SpawnerId\":-1797797444,\"ActorSeed\":787901937,\"VariationId\":0,\"State\":2,\"GraphMask\":1,\"EquippedItems\":null,\"OutfitId\":-1,\"NextGiftTime\":0.0,\"LastVisitTime\":0.0,\"Stats\":{\"Health\":999.0,\"Anger\":0.0,\"Fear\":0.0,\"Fullness\":100,\"Hydration\":100,\"Energy\":90.5,\"Affection\":999.0},\"StateFlags\":0},'
        $content = $content -replace $find, $replace
        write-host "." -NoNewline
    }
    write-host ""

    # Insert Kelvin
    write-host "Process Kelvin" -NoNewline
    for ($i = 0; $i -lt $kelvins; $i++)
    {
        $maxUniqueId++
        $find = '[\\]["]Actors[\\]["][:][\[]'
        $replace = '\"Actors\":[{\"UniqueId\":'+$maxUniqueId+',\"TypeId\":9,\"FamilyId\":0,\"Position\":'+$postion+',\"Rotation\":{\"x\":0.0,\"y\":-0.9923399,\"z\":0.0,\"w\":0.123537354},\"SpawnerId\":0,\"ActorSeed\":-37402917,\"VariationId\":0,\"State\":2,\"GraphMask\":1,\"EquippedItems\":[504],\"OutfitId\":-1,\"NextGiftTime\":0.0,\"LastVisitTime\":-100.0,\"Stats\":{\"Health\":999.0,\"Anger\":91.19554,\"Fear\":99.97499,\"Fullness\":45.9295425,\"Hydration\":18.3870544,\"Energy\":90.5,\"Affection\":0.0},\"StateFlags\":0},'
        $content = $content -replace $find, $replace
        write-host "." -NoNewline
    }
    write-host ""

    if (writeSavegame $SaveDataPath $content) {
        write-host ($SaveDataPath + " savegame modified") -ForegroundColor green -BackgroundColor Black
    }
    else {
        write-host ($SaveDataPath + " could not write to savegame") -ForegroundColor yellow -BackgroundColor Black
        return $false
    }
    return $true
}

function copyInventory
{
    param(
        [string]$lastestpath
    )

    $sourcePath = ($PSScriptRoot+"\PlayerInventorySaveData.json")
    if(!(test-path -path $sourcePath))
    {
        write-host ($sourcePath + " does not exist") -ForegroundColor White -BackgroundColor Red
        return $false
    }
    write-host ($sourcePath + " has been found") -ForegroundColor green -BackgroundColor Black

    Copy-Item -path $sourcePath -Destination $lastestpath -Force
    write-host ("Copy to: "+$lastestpath) -ForegroundColor green -BackgroundColor Black
    write-host "Check out your inventory" -ForegroundColor green -BackgroundColor Black
}

function getSavegame {
    param(
        [string]$filepath
    )

    if (!(test-path -path $filepath)) {
        write-host ($filepath + " does not exist") -ForegroundColor White -BackgroundColor Red
        return $false
    }

    return (Get-Content -Raw $filepath)
}

function writeSavegame {
    param(
        [string]$filepath,
        [string]$content
    )

    if (!(test-path -path $filepath)) {
        write-host ($filepath + " does not exist") -ForegroundColor White -BackgroundColor Red
        return $false
    }

    $Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
    [System.IO.File]::WriteAllLines($filepath, $content, $Utf8NoBomEncoding)
    return $true
}

function showMenu
{
    write-host "Important: Make sure your desired savegame has been saved last" -ForegroundColor Yellow
    write-host ""
    write-host "What can I do for you today?"
    write-host "1. Insert your inventory (PlayerInventorySaveData.json must be in script folder)"
    write-host "2. Revive your NPCs (All of them)"
    write-host "3. Insert additional Virginas and Kelvins to your game"

    $choice = 0
    while ($choice -le 0 -or $choice -gt 3)
    {
        $choice = read-host "Enter number (1-3)"
    }
    return $choice
}

function initHelper
{
    $choice = showMenu

    # Inventory
    if($choice -eq 1)
    {
        $lastestpath = retriveLatestSavegame
        $result      = copyInventory $lastestpath
    }

    # Revive NPCs
    if($choice -eq 2)
    {
        $lastestpath = retriveLatestSavegame "Multiplayer,SinglePlayer"
        $result      = reviveNPCs $lastestpath
    }

    # Add NPCs
    if($choice -eq 3)
    {
        $lastestpath = retriveLatestSavegame "Multiplayer,SinglePlayer"
        $result      = copyNPCs $lastestpath
    }
    
    return $result
}

$result = initHelper
$result
