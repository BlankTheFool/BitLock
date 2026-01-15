#region Admin-Elevation
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoExit", "-File `" $($MyInvocation.MyCommand.Definition)`""
    exit
}
#endregion   

if([Environment]::Is64BitProcess){
    #region GUI
    Add-Type -AssemblyName System.Windows.Forms

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "BitLock"
    $form.Size = New-Object System.Drawing.Size(300,315)
    $form.StartPosition = 'CenterScreen'

    #region DriveList
    $drive = New-Object System.Windows.Forms.Label
    $drive.Location = New-Object System.Drawing.Point(10,10)
    $drive.Size = New-Object System.Drawing.Size(280,20)
    $drive.Text = "Please select a drive (only select one):"
    $form.Controls.Add($drive)
    
    $DriveList = New-Object System.Windows.Forms.ListView
    $DriveList.Location= New-Object System.Drawing.Point(10,30)
    $DriveList.Size = New-Object System.Drawing.Size(260,120)
    $DriveList.View = "Details"
    $DriveList.GridLines = $True
    $DriveList.FullRowSelect = $True
    
    $DriveList_Column = New-Object System.Windows.Forms.ColumnHeader
    $DriveList_Column.Text = "DriveLetter"
    $DriveList_Column.Width = 100

    $DriveList_Column2 = New-Object System.Windows.Forms.ColumnHeader
    $DriveList_Column2.Text = "VolumeName"
    $DriveList_Column2.Width = -2
    
    $DriveList.Columns.AddRange(@($DriveList_Column,$DriveList_Column2))

    #driveFilter and adding drives to DriveList
    foreach($disk in (Get-Disk | Where-Object {$_.OperationalStatus -ne "No Media" -and $_.NumberOfPartitions -gt "0" -and $_.Number -ne (Get-Partition -DriveLetter "C").DiskNumber})){
        $letter = Get-Partition -DiskNumber $disk.Number | Where-Object {$_.Type -ne "System" -xor $_.Type -ne "Reserved" -xor $_.Type -ne "Recovery"}
        $Volume = Get-Volume -DriveLetter $letter.DriveLetter | Where-Object {$_.OperationalStatus -ne "Unknown"}
        foreach($V in $Volume){
            $DriveList_Item = New-Object System.Windows.Forms.ListViewItem
            $DriveList_Item.Text = $($V.DriveLetter)
            $DriveList_Item.SubItems.Add($($V.FileSystemLabel))
            $DriveList.Items.Add($DriveList_Item)
        }
    }
    $Form.Controls.Add($DriveList)
    #endregion
    
    #region DriveName
    $Name = New-Object System.Windows.Forms.Label
    $Name.Location = New-Object System.Drawing.Point(10,160)
    $Name.Size = New-Object System.Drawing.Size(280,20)
    $Name.Text = "enter a name for your Bitlocker drive:"
    $form.Controls.Add($Name)

    $NameBox = New-Object System.Windows.Forms.TextBox
    $NameBox.Location = New-Object System.Drawing.Point(10,180)
    $NameBox.Size = New-Object System.Drawing.Size(260,20)
    $form.Controls.Add($NameBox)
    #endregion

    #region FileSystem
    $Filesystem = New-Object System.Windows.Forms.Label
    $Filesystem.Location = New-Object System.Drawing.Point(10,205)
    $Filesystem.Size = New-Object System.Drawing.Size(280,20)
    $Filesystem.Text = "Filesystem:"
    $form.Controls.Add($Filesystem)

    $FilesystemBox = New-Object System.Windows.Forms.ComboBox
    $FilesystemBox.Location = New-Object System.Drawing.Point(10,225)
    $FilesystemBox.Size = New-Object System.Drawing.Size(260,20)
    $FilesystemBox.Items.AddRange(@("NTFS", "FAT32","exFAT"))
    $form.Controls.Add($FilesystemBox)
    #endregion

    #region buttons
    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Location = New-Object System.Drawing.Point(75,250)
    $okButton.Size = New-Object System.Drawing.Size(75,23)
    $okButton.Text = 'OK'
    $okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.AcceptButton = $okButton
    $form.Controls.Add($okButton)

    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Location = New-Object System.Drawing.Point(150,250)
    $cancelButton.Size = New-Object System.Drawing.Size(75,23)
    $cancelButton.Text = 'Cancel'
    $cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.CancelButton = $cancelButton
    $form.Controls.Add($cancelButton)
    #endregion

    $form.BringToFront()
    clear #clears console to make space for actually needed outputs
    #endregion
    
    if ($form.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){
        $Partition = Get-Partition -DriveLetter $DriveList.Items[$($DriveList.SelectedItems.Index)].Text # grabs the drive letter of the selected drive, cursed but works
        
        #region format, partition, name
        Clear-Disk -Number $Partition.DiskNumber -RemoveData -Confirm:$false
        if((Get-Disk | Where-Object{$_.DiskNumber -eq $Partition.DiskNumber}).PartitionStyle -eq "RAW"){
            Initialize-Disk -Number $Partition.DiskNumber -PartitionStyle GPT -Confirm:$false
        }
        New-Partition -DiskNumber $Partition.DiskNumber -UseMaximumSize -AssignDriveLetter | Out-Null
        $driveLetter = (Get-Partition -DiskNumber $Partition.DiskNumber).DriveLetter #grabs newly assigned drive letter
        Format-Volume -DriveLetter $driveLetter -FileSystem $FilesystemBox.SelectedItem -Confirm:$false | Out-Null
        Write-Host "Drive has been formatted and mounted as ${driveLetter}" -ForegroundColor Green
        Set-Volume -DriveLetter $driveLetter -NewFileSystemLabel $NameBox.Text
        Write-Host "Volume has been named as: $($NameBox.Text)" -ForegroundColor Green
        #endregion

        function GeneratePassword {
            $Length = 32  # Default password length
            $Lower = 'abcdefghijklmnopqrstuvwxyz'
            $Upper = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
            $Numbers = '0123456789'
            $Special = '!#$?'
            $AllChars = $Lower + $Upper + $Numbers + $Special
            $Password = @()
            
            $Password += $Lower[(Get-Random -Maximum $Lower.Length)]
            $Password += $Upper[(Get-Random -Maximum $Upper.Length)]
            $Password += $Numbers[(Get-Random -Maximum $Numbers.Length)]
            $Password += $Special[(Get-Random -Maximum $Special.Length)]
            $RemainingLength = $Length - $Password.Count
            $Password += -join (1..$RemainingLength | ForEach-Object { $AllChars[(Get-Random -Maximum $AllChars.Length)] })
            $Password = -join ($Password | Get-Random -Count $Password.Length)

            return $Password
        }

        #region encryption
        $password = GeneratePassword #we kinda need it in plain text for the password file
        Write-Host "Starting Bitlocker" -ForegroundColor Yellow
        Enable-BitLocker -MountPoint "${driveLetter}" -PasswordProtector -Password (ConvertTo-SecureString $password -AsPlainText -Force) -EncryptionMethod XtsAes256 -UsedSpaceOnly | Out-Null
        Add-BitLockerKeyProtector -MountPoint "${driveLetter}" -RecoveryPasswordProtector | Out-Null

        do {
            $BitlockerVolume = Get-BitLockerVolume -MountPoint "${driveLetter}"
            Write-Host "Waiting for Bitlocker to complete it's task" -ForegroundColor Yellow
            sleep 5
        } while ($BitlockerVolume.ProtectionStatus -ne "On")

        #endregion
        
        #weird indentation below but code breaks otherwise, soooo yeah
        #region Password File
        New-Item "C:\Users\$env:Username\Downloads\$($NameBox.Text)_Bitlocker_$(Get-Date -Format "dd_MM_yyyy").txt" -Value @"
Password	 : $password
KeyProtectorId 	 : $(($BitlockerVolume.KeyProtector | Where-Object { $_.KeyProtectorType -eq 'RecoveryPassword' }).KeyProtectorId)
RecoveryPassword : $(($BitlockerVolume.KeyProtector | Where-Object { $_.KeyProtectorType -eq 'RecoveryPassword' }).RecoveryPassword)
"@ -Force | Out-Null
        #endregion

        #region finale output
        Write-Host @"
Name		     : $($NameBox.Text)
Savepath .txt	     : C:\Users\$env:Username\Downloads\$($NameBox.Text)_Bitlocker_$(Get-Date -Format "dd_MM_yyyy").txt
VolumeStatus	     : $($BitlockerVolume.VolumeStatus)
ProtectionStatus     : $($BitlockerVolume.ProtectionStatus)

EncryptionPercentage : $($BitlockerVolume.EncryptionPercentage)%
"@ -ForegroundColor Green
        #endregion
    }
}
else{
    Write-Host "Process not 64-bit, aborting" -ForegroundColor Red
}

Set-ExecutionPolicy Restricted -Scope CurrentUser

