# TCC Installation Script

Allows you to install [TCC](https://www.bellard.org/tcc/), the Tiny C Compiler, and its Windows headers quickly and easily.

You can download this script by right-clicking on [this link](https://github.com/cntools/Install-TCC/raw/master/Install-TCC.ps1) and clicking on "Save Link As...". Once downloaded, make sure to right-click it, click Properties. Then check the "Unblock" option near the bottom, and click OK.

## Usage
From PowerShell:
```
.\Install-TCC.ps1 [-Destination Path] [-NoPath]
```

For most use cases, simply running `.\Install-TCC.ps1` with no additional arguments is recommended.

If you get an error about execution policies, this is because PowerShell scripts are disabled by default on Windows computers. To enable them, run the following first:
```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```
You can [learn more about execution policies here](https:/go.microsoft.com/fwlink/?LinkID=135170).

## Options
By default, TCC is installed to `C:\Program Files\TCC\` or the equivalent on your system. You can specify a different folder with `-Destination`. If the folder doesn't exist, it will be created. If it contains files, the script will offer to create a subfolder.

By default, the script will add TCC to the system-wide PATH environment variable, so that you can easily call `tcc.exe` from any terminal, without needing to specify the path to it. If you do not wish to do this, use the `-NoPath` argument. If the installation location is already present on the PATH, it will not be edited.

Adding to the system PATH variable, and writing to `C:\Program Files\` requires an administrator account (the script will auto-elevate in this case). Users without administrator access can still use the script by specifying `-NoPath` and using a destination they have write permissions for.