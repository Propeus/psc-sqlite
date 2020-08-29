
class DllLib{
    [string]$System_Data_SQLite_Dll 
    [string]$SQLite_Interop_Arm 
    [string]$SQLite_Interop_Linux 
    [string]$SQLite_Interop_Mac 
    [string]$SQLite_Interop_Windows
}

class HashLib{
    [string]$System_Data_SQLite_Dll 
    [string]$SQLite_Interop_Arm 
    [string]$SQLite_Interop_Linux 
    [string]$SQLite_Interop_Mac 
    [string]$SQLite_Interop_Windows
}


function Install(){
    [byte[]]$bytes=$null;
    [string]$Hashb64="";
    [System.Security.Cryptography.MD5CryptoServiceProvider]$Hasher = New-Object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider
    [HashLib]$SQLite_hash = [HashLib](Get-Content -path "HashLib.json"| ConvertFrom-Json);

    if(-not (Test-Path -Path "$PSScriptRoot/SQLite.Interop.dll")){
        [DllLib]$SQLite_lib=$null;
        $SQLite_lib = [DllLib](Get-Content -Path "./LibJson.json" | ConvertFrom-Json);
        
        $os = [System.Environment]::OSVersion.Platform;
            
        if($IsLinux){ 
            $bytes = [System.Convert]::FromBase64String($SQLite_lib.SQLite_Interop_Linux)
        }
        if($IsWindows){
            $bytes = [System.Convert]::FromBase64String($SQLite_lib.SQLite_Interop_Windows)
        }
        if($IsMacOs){
            $bytes = [System.Convert]::FromBase64String($SQLite_lib.SQLite_Interop_Mac)
        }

        [System.IO.File]::WriteAllBytes("$PSScriptRoot/SQLite.Interop.dll",$bytes)
    }else{
        $bytes= [System.IO.File]::ReadAllBytes("$PSScriptRoot/SQLite.Interop.dll");
        $md5 = $Hasher.ComputeHash($bytes)
        $Hashb64= [System.Convert]::ToBase64String($md5);
        [bool]$HashIgual=$false;
        if($script:IsLinux){
            $HashIgual = $Hashb64 -eq $SQLite_hash.SQLite_Interop_Linux
        }
        if($script:IsWindows){
            $HashIgual = $Hashb64 -eq $SQLite_hash.SQLite_Interop_Windows
        }
        if($script:IsMacOs){
            $HashIgual = $Hashb64 -eq $SQLite_hash.SQLite_Interop_Mac
        }

        if(-not ($HashIgual)){
            Remove-Item -Path "$PSScriptRoot/SQLite.Interop.dll"
            Install;
        }

    }

    if(-not (Test-Path -Path "$PSScriptRoot/System.Data.SQLite.dll")){
        $SQLite_lib = Get-Content -Path "$PSScriptRoot/LibJson.json" | ConvertFrom-Json;
        [byte[]]$bytes=$null;

        $bytes = [System.Convert]::FromBase64String($SQLite_lib.System_Data_SQLite_Dll)

        [System.IO.File]::WriteAllBytes("$PSScriptRoot/System.Data.SQLite.dll",$bytes)
    }else{
        $bytes= [System.IO.File]::ReadAllBytes("$PSScriptRoot/System.Data.SQLite.dll");
        $md5 = $Hasher.ComputeHash($bytes)
        $Hashb64= [System.Convert]::ToBase64String($md5);
        [bool]$HashIgual=$false;
    
        $HashIgual = $Hashb64 -eq $SQLite_hash.System_Data_SQLite_Dll

        if(-not ($HashIgual)){
            Remove-Item -Path "$PSScriptRoot/System.Data.SQLite.dll"
            Install-Sqlite;
        }
    }
}

Install;

class PscSqlite{

    [string]$PathFile;
    [string]$ConnectionString;
    $Connection;
    [bool]$IsOpen;
    [bool]$ManualOpenClose=$false

    PscSqlite(){
       Add-Type -Path "System.Data.SQLite.dll";

        $this.PathFile = ":memory:"
        $this.ConnectionString = 'Data Source={0}' -f $this.PathFile;
        $this.Connection = New-Object -TypeName System.Data.SQLite.SQLiteConnection;
        $this.Connection.ConnectionString = $this.ConnectionString;
    }

    PscSqlite($PathFile){
       Add-Type -Path "System.Data.SQLite.dll";

        if(-not (Split-Path $PathFile -IsAbsolute)){
            $this.PathFile = Join-Path $PSScriptRoot $PathFile;
        }else{
            $this.PathFile = $PathFile
        }

        $this.ConnectionString = 'Data Source={0}' -f $this.PathFile;
        $this.Connection = New-Object -TypeName System.Data.SQLite.SQLiteConnection;
        $this.Connection.ConnectionString = $this.ConnectionString;
    }

    
    Open(){
        if(-not $this.IsOpen -and -not $this.ManualOpenClose){
            $this.Connection.Open();
        }
    }

    Close(){
        if($this.IsOpen -and -not $this.ManualOpenClose){
            $this.Connection.Close();
        }
    }

    [bool]Exists(){
        return Test-Path $this.PathFile
    }

    [int]ExecuteNonQuery([string]$Query){
        $this.Open();
        $command = $this.Connection.CreateCommand();
        $command.CommandText = $Query;
        $linhas = $command.ExecuteNonQuery();
        $this.Close();
        return $linhas;
    }
    
    [PSObject]ExecuteReader([string]$Query){
        $this.Open();
        $command = $this.Connection.CreateCommand();
        $command.CommandText = $Query;
        $reader = $command.ExecuteReader();
        return $reader;
    }

    [System.Collections.Generic.List[PSObject]]Execute([string]$Query){
        $Reader= $this.ExecuteReader($Query);
        [System.Collections.Generic.List[PSObject]]$linhas = [System.Collections.Generic.List[PSObject]]::new($Reader.FieldCount);
        while($Reader.Read()){
            [PSObject]$linha = [PSObject]::new()
            for ([int]$i = 0; $i -lt $Reader.FieldCount; $i++) 
            {
                $linha | Add-Member -NotePropertyName $Reader.GetName($i) -NotePropertyValue $Reader.GetValue($i);
            }  
            $linhas.Add($linha)
        }
        $this.Close();
        return $linhas;
    }
}

function New-PscSqlite{
    param(
        [string]
        $PathFile
    )

    process{
        if($PathFile){
            $cls = [PscSqlite]::new($PathFile);
        }else{
            $cls = [PscSqlite]::new();
        }
        return $cls
    }
}

Export-ModuleMember New-PscSqlite;