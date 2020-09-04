
class DllLib {
    [string]$System_Data_SQLite_Dll 
    [string]$SQLite_Interop_Arm 
    [string]$SQLite_Interop_Linux 
    [string]$SQLite_Interop_Mac 
    [string]$SQLite_Interop_Windows
}

class HashLib {
    [string]$System_Data_SQLite_Dll 
    [string]$SQLite_Interop_Arm 
    [string]$SQLite_Interop_Linux 
    [string]$SQLite_Interop_Mac 
    [string]$SQLite_Interop_Windows
}


function Install() {
    [byte[]]$bytes = $null;
    [string]$Hashb64 = "";
    [System.Security.Cryptography.MD5CryptoServiceProvider]$Hasher = New-Object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider
    [HashLib]$SQLite_hash = [HashLib](Get-Content -path "Hash.json" | ConvertFrom-Json);

    if (-not (Test-Path -Path "$PSScriptRoot/SQLite.Interop.dll")) {
        [DllLib]$SQLite_lib = $null;
        $SQLite_lib = [DllLib](Get-Content -Path "./Lib.json" | ConvertFrom-Json);
                   
        if ($IsLinux) { 
            $bytes = [System.Convert]::FromBase64String($SQLite_lib.SQLite_Interop_Linux)
        }
        if ($IsWindows) {
            $bytes = [System.Convert]::FromBase64String($SQLite_lib.SQLite_Interop_Windows)
        }
        if ($IsMacOs) {
            $bytes = [System.Convert]::FromBase64String($SQLite_lib.SQLite_Interop_Mac)
        }

        [System.IO.File]::WriteAllBytes("$PSScriptRoot/SQLite.Interop.dll", $bytes)
    }
    else {
        $bytes = [System.IO.File]::ReadAllBytes("$PSScriptRoot/SQLite.Interop.dll");
        $md5 = $Hasher.ComputeHash($bytes)
        $Hashb64 = [System.Convert]::ToBase64String($md5);
        [bool]$HashIgual = $false;
        if ($script:IsLinux) {
            $HashIgual = $Hashb64 -eq $SQLite_hash.SQLite_Interop_Linux
        }
        if ($script:IsWindows) {
            $HashIgual = $Hashb64 -eq $SQLite_hash.SQLite_Interop_Windows
        }
        if ($script:IsMacOs) {
            $HashIgual = $Hashb64 -eq $SQLite_hash.SQLite_Interop_Mac
        }

        if (-not ($HashIgual)) {
            Remove-Item -Path "$PSScriptRoot/SQLite.Interop.dll"
            Install;
        }

    }

    if (-not (Test-Path -Path "$PSScriptRoot/System.Data.SQLite.dll")) {
        $SQLite_lib = Get-Content -Path "$PSScriptRoot/Lib.json" | ConvertFrom-Json;
        [byte[]]$bytes = $null;

        $bytes = [System.Convert]::FromBase64String($SQLite_lib.System_Data_SQLite_Dll)

        [System.IO.File]::WriteAllBytes("$PSScriptRoot/System.Data.SQLite.dll", $bytes)
    }
    else {
        $bytes = [System.IO.File]::ReadAllBytes("$PSScriptRoot/System.Data.SQLite.dll");
        $md5 = $Hasher.ComputeHash($bytes)
        $Hashb64 = [System.Convert]::ToBase64String($md5);
        [bool]$HashIgual = $false;
    
        $HashIgual = $Hashb64 -eq $SQLite_hash.System_Data_SQLite_Dll

        if (-not ($HashIgual)) {
            Remove-Item -Path "$PSScriptRoot/System.Data.SQLite.dll"
            Install-Sqlite;
        }
    }
}

Install;

class PscSqlite {

    [string]$PathFile;
    [string]$ConnectionString;
    $Connection;
    [bool]$IsOpen;
    [bool]$ManualOpenClose = $false

    PscSqlite() {
        Add-Type -Path "System.Data.SQLite.dll";

        $this.PathFile = ":memory:"
        $this.ConnectionString = 'Data Source={0}' -f $this.PathFile;
        $this.Connection = New-Object -TypeName System.Data.SQLite.SQLiteConnection;
        $this.Connection.ConnectionString = $this.ConnectionString;
    }
    PscSqlite($PathFile) {
        Add-Type -Path "System.Data.SQLite.dll";

        if (-not (Split-Path $PathFile -IsAbsolute)) {
            $this.PathFile = Join-Path $PSScriptRoot $PathFile;
        }
        else {
            $this.PathFile = $PathFile
        }

        $this.ConnectionString = 'Data Source={0}' -f $this.PathFile;
        $this.Connection = New-Object -TypeName System.Data.SQLite.SQLiteConnection;
        $this.Connection.ConnectionString = $this.ConnectionString;
    }    
    Open() {
        if (-not $this.IsOpen -and -not $this.ManualOpenClose) {
            $this.Connection.Open();
            $this.IsOpen = $true;
        }
    }
    Close() {
        if ($this.IsOpen -and -not $this.ManualOpenClose) {
            $this.Connection.Close();
            $this.IsOpen = $false;
        }
    }
    Dispose() {
        $this.Close();
        $this.Connection.Dispose();
    }
    [bool]Exists() {
        return Test-Path $this.PathFile
    }
    [int]ExecuteNonQuery([string]$Query) {
        $this.Open();
        $command = $this.Connection.CreateCommand();
        $command.CommandText = $Query;
        $linhas = $command.ExecuteNonQuery();
        $this.Close();
        return $linhas;
    }
    [PSObject]ExecuteReader([string]$Query) {
        $this.Open();
        $command = $this.Connection.CreateCommand();
        $command.CommandText = $Query;
        $reader = $command.ExecuteReader();
        return $reader;
    }
    [System.Collections.Generic.List[PSObject]]Execute([string]$Query) {
        $Reader = $this.ExecuteReader($Query);
        [System.Collections.Generic.List[PSObject]]$linhas = [System.Collections.Generic.List[PSObject]]::new($Reader.FieldCount);
        while ($Reader.Read()) {
            [PSObject]$linha = [PSObject]::new()
            for ([int]$i = 0; $i -lt $Reader.FieldCount; $i++) {
                $linha | Add-Member -NotePropertyName $Reader.GetName($i) -NotePropertyValue $Reader.GetValue($i);
            }  
            $linhas.Add($linha)
        }
        $this.Close();
        return $linhas;
    }
    CreateTableFromType([System.Type]$Type, [bool]$autoIncrement, [bool]$dropTable, [bool]$ignoreIfExists) {

        [System.Text.StringBuilder]$Query = [System.Text.StringBuilder]::new();

        if ($dropTable) {
            $Query.Append("DROP TABLE IF EXISTS ").Append($Type.Name.ToUpper()).AppendLine(";");
        }

        $Query.Append("CREATE TABLE ")
        
        if ($ignoreIfExists) {
            $Query.Append("IF NOT EXISTS ");
        }

        $Query.Append($Type.Name.ToUpper()).AppendLine("(");
        $properties = $Type.GetProperties();
        for ($i = 0; $i -lt $properties.Count; $i++) {
            
            $Query.Append($properties[$i].Name).Append(" ");

            #
            # Type?
            #

            if ($properties[$i].PropertyType.Name -eq "Int32") {
                $Query.Append("INTEGER").Append(" ");
            }
            elseif ($properties[$i].PropertyType.Name -eq "String") {
                $Query.Append("TEXT").Append(" ");
            }
            elseif ($properties[$i].PropertyType.Name -eq "Byte") {
                $Query.Append("NONE").Append(" ");
            }
            elseif ($properties[$i].PropertyType.Name -eq "Double" -or $properties[$i].PropertyType.Name -eq "Single") {
                $Query.Append("REAL").Append(" ");
            }
            elseif ($properties[$i].PropertyType.Name -eq "Boolean" -or $properties[$i].PropertyType.Name -eq "DateTime" -or $properties[$i].PropertyType.Name -eq "Decimal") {
                $Query.Append("NUMERIC").Append(" ");
            }
            else {
                
                #
                # Nullable?
                #

                if ($null -ne [System.Nullable]::GetUnderlyingType($properties[$i].PropertyType)) {
                    $nlType = [System.Nullable]::GetUnderlyingType($properties[$i].PropertyType);

                    if ($nlType.Name -eq "Int32") {
                        $Query.Append("INTEGER").Append(" ");
                    }
                    elseif ($nlType.Name -eq "Byte") {
                        $Query.Append("NONE").Append(" ");
                    }
                    elseif ($nlType.Name -eq "Double" -or $nlType.Name -eq "Single") {
                        $Query.Append("REAL").Append(" ");
                    }
                    elseif ($nlType.Name -eq "Boolean" -or $nlType.Name -eq "DateTime" -or $nlType.Name -eq "Decimal") {
                        $Query.Append("NUMERIC").Append(" ");
                    }
                    else {
                        $Query.Append("NONE").Append(" ");
                    }
                }
            }



            #
            # Attribute?
            #

            foreach ($item in $properties[$i].GetCustomAttributes($false)) {
                if ($item.GetType() -eq [System.ComponentModel.DataAnnotations.RequiredAttribute]) {
                    $Query.Append("NOT NULL").Append(" ");
                }
    
                if ($item.GetType() -eq [System.ComponentModel.DataAnnotations.KeyAttribute]) {
                    $Query.Append("PRIMARY KEY").Append(" ");

                    if ($autoIncrement) {
                        $Query.Append("AUTOINCREMENT").Append(" ");
                    }
                }
            }
                        

            if ($i -lt $properties.Count - 1) {
                $Query.Append(",").AppendLine();
            }
            else {
                $Query.AppendLine();
            }
        }
        $Query.AppendLine(");")

        $this.ExecuteNonQuery($Query.ToString());
    }
    CreateTableFromType([System.Type]$Type) {
        $this.CreateTableFromType($Type, $true, $false, $false)
    }
    CreateTableIfNotExistsFromType([System.Type]$Type) {
        $this.CreateTableFromType($Type, $true, $false, $true)
    }
    RecreateTableFromType([System.Type]$Type) {
        $this.CreateTableFromType($Type, $true, $true, $false)
    }
    InsertFromObject($value) {
        [System.Type]$type = $value.GetType();
        $this.CreateTableIfNotExistsFromType($type);
        [System.Text.StringBuilder]$Query = [System.Text.StringBuilder]::new();
        $Query.Append("INSERT INTO ").Append($type.Name).Append(" (");
        $properties = $type.GetProperties();
        for ($i = 0; $i -lt $properties.Count; $i++) {
            #
            # Attribute?
            #
            [bool]$isID = $false;
            foreach ($item in $properties[$i].GetCustomAttributes($false)) {    
                if ($item.GetType() -eq [System.ComponentModel.DataAnnotations.KeyAttribute]) {
                    $pname = $properties[$i].Name;
                    $valueItem = $value.$pname;
                    $defaultValue = [System.Activator]::CreateInstance($properties[$i].PropertyType)
                    $isID = $valueItem -eq $defaultValue;
 
                }
            }
           
            if (-not $isID) {
                $Query.Append($properties[$i].Name);
                if ($i -lt $properties.Count - 1) {
                    $Query.Append(",")
                }
            }

            
        }

        $Query.Append(") VALUES (");
        $properties = $type.GetProperties();
        for ($i = 0; $i -lt $properties.Count; $i++) {
            $pname = $properties[$i].Name;

            #
            # Attribute?
            #
            [bool]$isID = $false;
            foreach ($item in $properties[$i].GetCustomAttributes($false)) {    
                if ($item.GetType() -eq [System.ComponentModel.DataAnnotations.KeyAttribute]) {
                    $pname = $properties[$i].Name;
                    $valueItem = $value.$pname;
                    $defaultValue = [System.Activator]::CreateInstance($properties[$i].PropertyType)
                    $isID = $valueItem -eq $defaultValue;
                }
            }
           
            if (-not $isID) {
                if ($properties[$i].PropertyType.Name -eq "Int32" -or $properties[$i].PropertyType.Name -eq "Byte") {
                    $Query.Append($value.$pname);
                }
                elseif ($properties[$i].PropertyType.Name -eq "String") {
                    $Query.Append("'").Append($value.$pname).Append("'");
                }
                elseif ($properties[$i].PropertyType.Name -eq "Double" -or $properties[$i].PropertyType.Name -eq "Single" -or $properties[$i].PropertyType.Name -eq "Decimal") {
                    $Query.Append(($value.$pname).ToString().Replace(",", "."));
                }
                elseif ($properties[$i].PropertyType.Name -eq "Boolean") {
                    $Query.Append([int]($value.$pname));
                }
                elseif ($properties[$i].PropertyType.Name -eq "DateTime" ) {
                    $Query.Append("'").Append($value.$pname).Append("'");
                }
                else {
                    $Query.Append("'").Append($value.$pname).Append("'");
                }


                if ($i -lt $properties.Count - 1) {
                    $Query.Append(",")
                }
            }

        
        }
        $Query.Append(");");
        #Write-Host $Query.ToString();
        $this.ExecuteNonQuery($Query.ToString());

    }
    [System.Collections.Generic.List[PSObject]]SelectFromObject($value) {
        return $this.SelectFromObject($value, $false)
    }
    [System.Collections.Generic.List[PSObject]]SelectFromObject($value, [bool]$LikeString) {
        [System.Type]$type = $value.GetType();
        $this.CreateTableIfNotExistsFromType($type);
        [System.Text.StringBuilder]$Query = [System.Text.StringBuilder]::new();
        $Query.Append("SELECT * FROM ").Append($type.Name).Append(" ");
        $properties = $type.GetProperties();
        $flg_next = $false;
        $flg_where = $true;
        for ($i = 0; $i -lt $properties.Count; $i++) {
            
            $pNme = $properties[$i].Name;
            $pValue = ($value.$pNme);
            $isDefault = $false;
            if ($properties[$i].PropertyType.IsValueType) {
                $defaultValue = [System.Activator]::CreateInstance($properties[$i].PropertyType)
                $isDefault = ($pValue -eq $defaultValue);
            }

            if ($null -ne $pValue -and (-not [string]::IsNullOrEmpty($pValue)) -and (-not $isDefault)) {
                if ($flg_where) {
                    $Query.Append("WHERE ");
                    $flg_where = $false;
                }

                if ($flg_next) {
                    $Query.Append(" OR ").Append(" ")
                    $flg_next = $false;
                }

                if ($properties[$i].PropertyType.Name -eq "String") {
                    $Query.Append($pNme)
                    if ($LikeString) {
                        $Query.Append(" LIKE ").Append("'%").Append($pValue).Append("%'");
                    }
                    else {
                        $Query.Append("=").Append("'").Append($pValue).Append("'");
                    }
                }
                else {
                    $Query.Append($pNme).Append("=").Append("'").Append($pValue).Append("'");
                }

                $flg_next = $true;
            }
        }
        $Query.Append(";");
        Write-Host $Query.ToString()
        return $this.Execute($Query.ToString());
    }
    UpdateFromObject($value) {
        [System.Type]$type = $value.GetType();
        $this.CreateTableIfNotExistsFromType($type);
        [System.Text.StringBuilder]$Query = [System.Text.StringBuilder]::new();
        $Query.Append("UPDATE ").Append($type.Name).Append(" SET ");
        $properties = $type.GetProperties();
        $flg_next = $false;
        for ($i = 0; $i -lt $properties.Count; $i++) {
            #
            # Attribute?
            #
            [bool]$isID = $false;
            foreach ($item in $properties[$i].GetCustomAttributes($false)) {    
                $isID = $item.GetType() -eq [System.ComponentModel.DataAnnotations.KeyAttribute] 
                if ($isID) {
                    break;
                }
            }
           
            if (-not $isID) {
                $pNme = $properties[$i].Name;
                $pValue = ($value.$pNme);
                if ($flg_next) {
                    $Query.Append(",")
                    $flg_next = $false;
                }
                $Query.Append($pNme).Append("=").Append("'").Append($pValue).Append("'");

                $flg_next = $true;
            }

            
        }

        $flg_next = $false;
        $Query.Append(" WHERE ");
        for ($i = 0; $i -lt $properties.Count; $i++) {
            #
            # Attribute?
            #
            [bool]$isID = $false;
            foreach ($item in $properties[$i].GetCustomAttributes($false)) {    
                $isID = $item.GetType() -eq [System.ComponentModel.DataAnnotations.KeyAttribute] 
                if ($isID) {
                    break;
                }
            }
           
            if ($isID) {
                $pNme = $properties[$i].Name;
                $pValue = ($value.$pNme);
                if ($flg_next) {
                    $Query.Append(" AND ")
                    $flg_next = $false;
                }
                $Query.Append($pNme).Append("=").Append("'").Append($pValue).Append("'");

                $flg_next = $true;
            }

            
        }
        $Query.Append(";");
        # Write-Host $Query.ToString();
        $this.ExecuteNonQuery($Query.ToString());
    }
    DeleteFromObject($value) {
        [System.Type]$type = $value.GetType();
        $this.CreateTableIfNotExistsFromType($type);
        [System.Text.StringBuilder]$Query = [System.Text.StringBuilder]::new();
        $Query.Append("DELETE FROM ").Append($type.Name);
        $properties = $type.GetProperties();

        $flg_next = $false;
        $Query.Append(" WHERE ");
        for ($i = 0; $i -lt $properties.Count; $i++) {
            #
            # Attribute?
            #
            [bool]$isID = $false;
            foreach ($item in $properties[$i].GetCustomAttributes($false)) {    
                $isID = $item.GetType() -eq [System.ComponentModel.DataAnnotations.KeyAttribute] 
                if ($isID) {
                    break;
                }
            }
           
            if ($isID) {
                $pNme = $properties[$i].Name;
                $pValue = ($value.$pNme);
                if ($flg_next) {
                    $Query.Append(" AND ")
                    $flg_next = $false;
                }
                $Query.Append($pNme).Append("=").Append("'").Append($pValue).Append("'");

                $flg_next = $true;
            }

            
        }
        $Query.Append(";");
        # Write-Host $Query.ToString();
        $this.ExecuteNonQuery($Query.ToString());
    }
    [bool]ExistsFromObject($value) {
        return $this.SelectFromObject($value).Count -ne 0;
    }
}

function New-PscSqlite {
    param(
        [string]
        $PathFile
    )

    process {
        if ($PathFile) {
            $cls = [PscSqlite]::new($PathFile);
        }
        else {
            $cls = [PscSqlite]::new();
        }
        return $cls
    }
}

function ConvertTo-PscSqliteType {
    param (
        # Lista a ser convertido
        [System.Collections.IEnumerable]
        [Parameter(Mandatory = $true, Position = 0)]
        $collection,
        # Tipo a ser convertido
        [Parameter(Mandatory = $true, Position = 1)]
        [System.Type]
        $type
    )

    begin {
        [System.Collections.ArrayList]$newCollection = [System.Collections.ArrayList]::new();
    }
    
    process {
        foreach ($item in $collection) {
            $newCollection.Add([System.Management.Automation.LanguagePrimitives]::ConvertTo($item, $type))>$null;
        }
    }

    end {
        return $newCollection;
    }
}

Export-ModuleMember New-PscSqlite;
Export-ModuleMember ConvertTo-PscSqliteType;