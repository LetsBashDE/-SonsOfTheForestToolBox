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
            $newNPC = $newNPC -replace '[\\]["]Stats[\\]["]:[{][^}]*[}],','\"Stats\":{\"Health\":9999,\"Anger\":60.25404,\"Fear\":99.97499,\"Fullness\":6.249775,\"Hydration\":0.0,\"Energy\":90.5,\"Affection\":0.0},'
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
            $newNPC = $newNPC -replace '[\\]["]Stats[\\]["]:[{][^}]*[}],','\"Stats\":{\"Health\":9999.0,\"Anger\":0.0,\"Fear\":0.0,\"Fullness\":0.0,\"Hydration\":0.0,\"Energy\":90.5,\"Affection\":100.0},'
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

function tameNPCs
{
    param(
        [string]$lastestpath
    )
    $SaveDataPath = ($lastestpath + "\SaveData.json")
    $content = getSavegame $SaveDataPath
    $original = $content 

    if ($content -like '*,\"TypeId\":10,*') {
        $NPCpattern = '[{][\\]["]UniqueId[\\]["][:][0-9]*[,][\\]["]TypeId[\\]["][:]10[,][^\}]*[}][^\}]*[}][^\}]*[}][,][\\]["]StateFlags[\\]["][:][0-9]{1,4}[}]';
        $NPCs = [regex]::Matches($content, $NPCpattern)
        foreach($oldNPC in $NPCs)
        {
            # Check if unique ID can be extracted
            if (!($oldNPC -like '*,*' -and $oldNPC -like '{\"UniqueId\":*'))
            {
                continue
            }
            
            # Extract unique ID
            $uniqueID = [int](($oldNPC -split ',')[0] -replace '[{][\\]["]UniqueId[\\]["][:]','')
            
            # Validate unique ID
            if(!($uniqueID -gt 0))
            {
                continue
            }

            # Update influence
            $influenceUpdate = '{\"UniqueId\":'+$uniqueID+',\"Influences\":[{\"TypeId\":\"Player\",\"Sentiment\":100,\"Anger\":0.0,\"Fear\":0.0},{\"TypeId\":\"Cannibal\",\"Sentiment\":0.0,\"Anger\":8.0,\"Fear\":35.0}]},'
            if ($content -like ('*{\"UniqueId\":'+$uniqueID+',\"Influences\":*'))
            {
                $influencePattern = '[{][\\]["]UniqueId[\\]["][:]'+$uniqueID+'[,][\\]["]Influences[\\]["][:][\[][^\]]*[\]][}][,]'
                $content = $content -replace $influencePattern,$influenceUpdate
            }
            else 
            {
                # Insert new influence
                $influencePattern = '[\\]["]InfluenceMemory[\\]["][:][\[]'
                $content = $content -replace $influencePattern,('\"InfluenceMemory\":['+$influenceUpdate)
            }

            # Update event
            #$eventUpdate = '{\"UniqueId\":'+$uniqueID+',\"Events\":[{\"Count\":0,\"Time\":0.0},{\"Count\":4,\"Time\":512.485046},{\"Count\":16,\"Time\":512.499634},{\"Count\":0,\"Time\":0.0},{\"Count\":11,\"Time\":516.4842},{\"Count\":0,\"Time\":0.0},{\"Count\":18,\"Time\":519.5603},{\"Count\":22,\"Time\":440.9344},{\"Count\":250,\"Time\":521.5445},{\"Count\":142,\"Time\":536.180237},{\"Count\":1,\"Time\":17.9985332},{\"Count\":0,\"Time\":0.0},{\"Count\":1,\"Time\":441.1082},{\"Count\":168,\"Time\":516.5881},{\"Count\":0,\"Time\":0.0},{\"Count\":13,\"Time\":442.068573},{\"Count\":0,\"Time\":0.0},{\"Count\":1,\"Time\":17.6253281},{\"Count\":3,\"Time\":222.579163}]},'
            $eventUpdate = '{\"UniqueId\":'+$uniqueID+',\"Events\":[{\"Count\":0,\"Time\":0.0},{\"Count\":6000,\"Time\":1},{\"Count\":100,\"Time\":2},{\"Count\":100,\"Time\":3},{\"Count\":100,\"Time\":4},{\"Count\":0,\"Time\":0.0},{\"Count\":100,\"Time\":5},{\"Count\":22,\"Time\":6},{\"Count\":250,\"Time\":7},{\"Count\":142,\"Time\":8},{\"Count\":1,\"Time\":9},{\"Count\":0,\"Time\":0.0},{\"Count\":1,\"Time\":10},{\"Count\":168,\"Time\":11},{\"Count\":0,\"Time\":0.0},{\"Count\":13,\"Time\":12},{\"Count\":0,\"Time\":0.0},{\"Count\":1,\"Time\":14},{\"Count\":3,\"Time\":0.15}]},'
            if ($content -like ('*{\"UniqueId\":'+$uniqueID+',\"Events\":*'))
            {
                $eventPattern = '[{][\\]["]UniqueId[\\]["][:]'+$uniqueID+'[,][\\]["]Events[\\]["][:][\[][^\]]*[\]][}][,]'
                $content = $content -replace $eventPattern,$eventUpdate
            }
            else 
            {
                # Insert new event
                $eventPattern = '[\\]["]EventMemory[\\]["][:][\[]'
                $content = $content -replace $eventPattern,('\"EventMemory\":['+$eventUpdate)
            }

            $newNPC = $oldNPC -replace '[\\]["]State[\\]["]:[0-9]{1,2}[,]','\"State\":2,'
            $newNPC = $newNPC -replace '[\\]["]LastVisitTime[\\]["]:[^,]*[,]','\"LastVisitTime\":1,'
            $newNPC = $newNPC -replace '[\\]["]NextGiftTime[\\]["]:[^,]*[,]','\"NextGiftTime\":11,'
            $newNPC = $newNPC -replace '[\\]["]EquippedItems[\\]["]:[^,]*[,]','\"EquippedItems\":[529],'
            $newNPC = $newNPC -replace '[\\]["]VariationId[\\]["]:[0-9]{1,2}[,]','\"VariationId\":1,'
            $newNPC = $newNPC -replace '[\\]["]Stats[\\]["]:[{][^}]*[}],','\"Stats\":{\"Health\":999.0,\"Anger\":0.0,\"Fear\":0.0,\"Fullness\":90.0,\"Hydration\":50.0,\"Energy\":90.5,\"Affection\":99.9733},'
            $content = $content -replace [regex]::escape($oldNPC), $newNPC

            # Event examples
            #{\"UniqueId\":873,\"Events\":[{\"Count\":0,\"Time\":0.0},{\"Count\":4,\"Time\":512.485046},{\"Count\":16,\"Time\":512.499634},{\"Count\":0,\"Time\":0.0},{\"Count\":11,\"Time\":516.4842},{\"Count\":0,\"Time\":0.0},{\"Count\":18,\"Time\":519.5603},{\"Count\":22,\"Time\":440.9344},{\"Count\":250,\"Time\":521.5445},{\"Count\":142,\"Time\":536.180237},{\"Count\":1,\"Time\":17.9985332},{\"Count\":0,\"Time\":0.0},{\"Count\":1,\"Time\":441.1082},{\"Count\":168,\"Time\":516.5881},{\"Count\":0,\"Time\":0.0},{\"Count\":13,\"Time\":442.068573},{\"Count\":0,\"Time\":0.0},{\"Count\":1,\"Time\":17.6253281},{\"Count\":3,\"Time\":222.579163}]}
            # \"EventMemory\":[

            # Influence examples
            # \"InfluenceMemory\":[
            # {\"UniqueId\":2147140407,\"Influences\":[{\"TypeId\":\"Player\",\"Sentiment\":0.0386166461,\"Anger\":0.0,\"Fear\":29.9227657},{\"TypeId\":\"Cannibal\",\"Sentiment\":0.0,\"Anger\":8.0,\"Fear\":35.0}]}
        }
        write-host ($SaveDataPath + " type id 10 (Virginia) is modified") -ForegroundColor green -BackgroundColor Black
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
    write-host "4. Tame all Virginas"

    $choice = 0
    while ($choice -le 0 -or $choice -gt 4)
    {
        $choice = read-host "Enter number (1-4)"
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
    
    # Tame Virginia
    if($choice -eq 4)
    {
        $lastestpath = retriveLatestSavegame "Multiplayer,SinglePlayer"
        $result      = tameNPCs $lastestpath
    }

    return $result
}

$result = initHelper
#$result
