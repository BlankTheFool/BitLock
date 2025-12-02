# BitLock
Bitlocker Tool with basic UI to encrypt your chosen data drive

# Why?
I needed a tool that automates the Bitlocker Process to a degree so that's what I created

# Features
- automatic admin elevation
- check that it's running in a 64Bit Process
- basic UI to select the data drive, Enter a name it has supposed to have and set a Fileysystem ("NTFS", "FAT32","exFAT")
- automatic 32 character Password generation with Lowercase, Uppercase, Numbers and Special Signs
- saves password, KeyProtectorID and RecoveryPassword in a TXT file in the Documents Folder of your User Directory with Filename-Format being
  "${Label}-Bitlocker-$(Get-Date -Format "dd_MM_yyyy").txt"
- final Output that displays: Label, SavePath, VolumeStatus, Protectionstatus and EncyrptionPercentage

# Drive Selection Filter
  Drive Selection doesn't display/filters the following:
  - Disks with OperationalStatus "No Media"
  - Disks with NumberOfPartitions "0"
  - Disks with DriveLetter "C" in order to avoid clearing you OS Drive
  - Partitions with PartitionType "System", "Reserved" or "Recovery"
  - Volumes with OperationalStatus "unknown"
