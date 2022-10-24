
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



class Sqlite : System.IDisposable {

    [string]$PathFile;
    [string]$ConnectionString;
    $Connection;
    [bool]$IsOpen;
    [bool]$ManualOpenClose = $false

    Sqlite() {
        $this.Init();

        Add-Type -Path "$PSScriptRoot/System.Data.SQLite.dll";

        $this.PathFile = ":memory:"
        $this.ConnectionString = 'Data Source={0}' -f $this.PathFile;
        $this.Connection = New-Object -TypeName System.Data.SQLite.SQLiteConnection;
        $this.Connection.ConnectionString = $this.ConnectionString;
    }
    Sqlite($PathFile) {
        $this.Init();

        Add-Type -Path "$PSScriptRoot/System.Data.SQLite.dll";

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

    hidden Init() {

        if (-not (Test-Path "$PSScriptRoot/Hash.json")) {
            throw "E necessario o arquivo de hash para inicializar o SQLite"
        }
        if (-not (Test-Path "$PSScriptRoot/Lib.json")) {
            throw "E necessario o arquivo com as DLLs para inicializar o SQLite"
        }

        [byte[]]$bytes = $null;
        [string]$Hashb64 = "";
        [System.Security.Cryptography.MD5CryptoServiceProvider]$Hasher = New-Object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider
        [HashLib]$SQLite_hash = [HashLib](Get-Content -path "$PSScriptRoot/Hash.json" | ConvertFrom-Json);

        #Verifica se a DLL é compativel com o S.O.
        if ((Test-Path -Path "$PSScriptRoot/SQLite.Interop.dll")) {
            $bytes = [System.IO.File]::ReadAllBytes("$PSScriptRoot/SQLite.Interop.dll");
            $md5 = $Hasher.ComputeHash($bytes)
            $Hashb64 = [System.Convert]::ToBase64String($md5);
            [bool]$HashIgual = $false;
            if ($global:IsLinux) {
                Write-Debug "Verificando SO Linux"
                $HashIgual = $Hashb64 -eq $SQLite_hash.SQLite_Interop_Linux
            }
            elseif ($global:IsWindows) {
                Write-Debug "Verificando SO Windows"
                $HashIgual = $Hashb64 -eq $SQLite_hash.SQLite_Interop_Windows
            }
            elseif ($global:IsMacOs) {
                Write-Debug "Verificando SO Mac"
                $HashIgual = $Hashb64 -eq $SQLite_hash.SQLite_Interop_Mac
            }
            else {
                throw "SO não identificado"
            }
    
            if (-not ($HashIgual)) {
                try {
                    Remove-Item -Path "$PSScriptRoot/SQLite.Interop.dll"
                }
                catch {
                    throw "Erro ao remover a DLL"   
                }
            }
        }

        if (Test-Path -Path "$PSScriptRoot/System.Data.SQLite.dll") {
            $bytes = [System.IO.File]::ReadAllBytes("$PSScriptRoot/System.Data.SQLite.dll");
            $md5 = $Hasher.ComputeHash($bytes)
            $Hashb64 = [System.Convert]::ToBase64String($md5);
            [bool]$HashIgual = $false;

            $HashIgual = $Hashb64 -eq $SQLite_hash.System_Data_SQLite_Dll

            if (-not ($HashIgual)) {
                Remove-Item -Path "$PSScriptRoot/System.Data.SQLite.dll"
            }
        }

        #Grava a DLL
        if (-not (Test-Path -Path "$PSScriptRoot/SQLite.Interop.dll")) {
            [DllLib]$SQLite_lib = $null;
            $SQLite_lib = [DllLib](Get-Content -Path "$PSScriptRoot/Lib.json" | ConvertFrom-Json);
                       
            if ($global:IsLinux) { 
                $bytes = [System.Convert]::FromBase64String($SQLite_lib.SQLite_Interop_Linux)
            }
            elseif ($global:IsWindows) {
                $bytes = [System.Convert]::FromBase64String($SQLite_lib.SQLite_Interop_Windows)
            }
            elseif ($global:IsMacOs) {
                $bytes = [System.Convert]::FromBase64String($SQLite_lib.SQLite_Interop_Mac)
            }
            else {
                Write-Error "SO não identificado"
            }
    
            [System.IO.File]::WriteAllBytes("$PSScriptRoot/SQLite.Interop.dll", $bytes)
        }

        if (-not (Test-Path -Path "$PSScriptRoot/System.Data.SQLite.dll")) {
            $SQLite_lib = Get-Content -Path "$PSScriptRoot/Lib.json" | ConvertFrom-Json;
            [byte[]]$bytes = $null;
    
            $bytes = [System.Convert]::FromBase64String($SQLite_lib.System_Data_SQLite_Dll)
    
            [System.IO.File]::WriteAllBytes("$PSScriptRoot/System.Data.SQLite.dll", $bytes)
        }
      
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
    
    [bool]Exists() {
        return Test-Path $this.PathFile
    }
    [int]ExecuteNonQuery([string]$Query, [bool]$notCloseConnection) {
        $this.Open();
        $command = $this.Connection.CreateCommand();
        $command.CommandText = $Query;
        [int]$_result = -1;
        try {
            $_result = $command.ExecuteNonQuery();
        }
        catch {
            Write-Error "Falha ao executar o comando: $Query" 
            throw;
        }
        finally {
            if (-not $notCloseConnection) {
                $this.Close();
            }
        }
        return $_result;
        
    }
    [int]ExecuteNonQuery([string]$Query) {
        return $this.ExecuteNonQuery($Query, $false);
    }
    [Int64]ExecuteScalar([string]$Query) {
        $this.Open();
        $command = $this.Connection.CreateCommand();
        $command.CommandText = $Query;
        [Int64]$_result = -1;
        try {
            $_result = [Int64]$command.ExecuteScalar();
        }
        catch {
            Write-Error "Falha ao executar o comando: $Query" 
            throw;
        }
        finally {
            $this.Close();
        }
        return $_result;
    }
    [PSObject]ExecuteReader([string]$Query) {
        $this.Open();
        $_command = $this.Connection.CreateCommand();
        $_command.CommandText = $Query;
        $_result = $null;
        try {
            $_result = $_command.ExecuteReader(); 
        }
        catch {
            Write-Error "Falha ao executar o comando: $Query" 
            throw;
        }
        return $_result;
    }
    [System.Collections.Generic.List[PSObject]]Execute([string]$Query) {
        $this.Open();
        $_command = $this.Connection.CreateCommand();
        $_command.CommandText = $Query;
        Write-Debug $Query;
        try {
            $_reader = $_command.ExecuteReader();
        }
        catch {
            Write-Error $Query;
            throw $_.Exception;
        }
        [System.Collections.Generic.List[PSObject]]$linhas = [System.Collections.Generic.List[PSObject]]::new($_reader.StepCount);
        while ($_reader.Read()) {
            [PSObject]$linha = [PSObject]::new()
            for ([int]$i = 0; $i -lt $_reader.FieldCount; $i++) {
                $nome = $_reader.GetName($i);
                $valor = $_reader.GetValue($i);
                if ($_reader.IsDBNull($i)) {
                    $valor = $null;
                }
                $linha | Add-Member -NotePropertyName $nome  -NotePropertyValue $valor;
            }  
            $linhas.Add($linha)
        }
        $this.Close();
        return $linhas;
    }
    Dispose() {
        $this.Close();
        $this.Connection.Dispose();
    }
}

class SqliteORM : Sqlite {

   

       
    CreateTableFromType([System.Type]$Type, [bool]$autoIncrement, [bool]$dropTable, [bool]$ignoreIfExists) {

        [System.Text.StringBuilder]$Query = [System.Text.StringBuilder]::new();
        [System.Text.StringBuilder]$FK_Query = [System.Text.StringBuilder]::new();

        [string]$SchemaTable = $Type.Name;
        [System.ComponentModel.DataAnnotations.Schema.TableAttribute]$table = [System.Attribute]::GetCustomAttribute($Type, [System.ComponentModel.DataAnnotations.Schema.TableAttribute]);
        if ($table) {
            if ($table.Schema) {
                $SchemaTable = "$($table.Schema)_$($table.Name)";
            }
            else {
                $SchemaTable = "$($table.Name)";
            }
        }

        if ($dropTable) {
            $Query.Append("DROP TABLE IF EXISTS ").Append($SchemaTable).AppendLine(";");
        }

        $Query.Append("CREATE TABLE ")
        
        if ($ignoreIfExists) {
            $Query.Append("IF NOT EXISTS ");
        }

        $Query.Append($SchemaTable).AppendLine("(");
        $properties = $Type.GetProperties();
        for ($i = 0; $i -lt $properties.Count; $i++) {
            
            if (-not($properties[$i].PropertyType.IsClass -and $properties[$i].Name.ToLower().Contains("navigation"))) {
                $Query.Append($properties[$i].Name).Append(" ");
            }

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
            elseif ($properties[$i].PropertyType.Name -eq "DateTime") {
                $Query.Append("DATETIME").Append(" ");
            }
            elseif ($properties[$i].PropertyType.Name -eq "Double" -or $properties[$i].PropertyType.Name -eq "Single") {
                $Query.Append("REAL").Append(" ");
            }
            elseif ($properties[$i].PropertyType.Name -eq "Boolean" ) {
                $Query.Append("BOOLEAN").Append(" ");
            }
            elseif ($properties[$i].PropertyType.Name -eq "Decimal") {
                $Query.Append("NUMERIC").Append(" ");
            }
            elseif ($properties[$i].PropertyType.IsClass -and $properties[$i].Name.ToLower().Contains("navigation")) {
                if ([System.Activator]::CreateInstance($properties[$i].PropertyType) -is [System.Collections.ICollection] -and $properties[$i].PropertyType.IsGenericType) {
                    $InnerType = $properties[$i].PropertyType.GetGenericArguments();
                    if ($InnerType.Count -eq 1) {
                        $this.CreateTableFromType($InnerType[0], $autoIncrement, $dropTable, $ignoreIfExists);
                    }

                }
                else {
                    $this.CreateTableFromType($properties[$i].PropertyType, $autoIncrement, $dropTable, $ignoreIfExists);
                }
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
                    elseif ($nlType.Name -eq "DateTime") {
                        $Query.Append("DATETIME").Append(" ");
                    }
                    elseif ($nlType.Name -eq "Double" -or $nlType.Name -eq "Single") {
                        $Query.Append("REAL").Append(" ");
                    }
                    elseif ($nlType.Name -eq "Boolean") {
                        $Query.Append("BOOLEAN").Append(" ");
                    }
                    elseif ($nlType.Name -eq "Decimal") {
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

                if ($item.GetType() -eq [System.ComponentModel.DataAnnotations.Schema.ForeignKeyAttribute]) {
                    [System.ComponentModel.DataAnnotations.Schema.ForeignKeyAttribute]$fk_table = [System.Attribute]::GetCustomAttribute($properties[$i], $item.GetType());
                    [string]$fk_name_table = $fk_table.Name;

                    if ($FK_Query.ToString() -ne [string]::Empty) {
                        $FK_Query.Append(",").AppendLine();    
                    }
                    $FK_Query.Append("FOREIGN KEY (").Append($properties[$i].Name).Append(") REFERENCES ").Append($fk_name_table).Append(" (").Append($properties[$i].Name).Append(")");
                }

            }
                        

            if (($i -lt $properties.Count - 1) -and (-not $properties[$i + 1].Name.ToLower().Contains("navigation"))) {
                $Query.Append(",").AppendLine();
            }
            else {
                if (($FK_Query.ToString() -ne [string]::Empty) -and (-not $properties[$i].Name.ToLower().Contains("navigation"))) {
                    $Query.Append(",")
                }
                $Query.AppendLine();
            }
        }

        $Query.Append($FK_Query.ToString()).AppendLine(");")

        try {
            Write-Debug $Query.ToString();
            $this.ExecuteNonQuery($Query.ToString());

        }
        catch {
            Write-Error $Query.ToString();
            throw $_.Exception;
        }
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

    [System.Collections.Generic.List[PSObject]]SelectFromObjectPaged($value, [int]$page) {
        return $this.SelectFromObject($value, $false, "AND", $true, $page, 100, $true);
    }
    [System.Collections.Generic.List[PSObject]]SelectFromObjectPaged($value, [bool]$LikeString, [int]$page) {
        return $this.SelectFromObject($value, $LikeString, "AND", $true, $page, 100, $true);
    }
    [System.Collections.Generic.List[PSObject]]SelectFromObjectPaged($value, [bool]$LikeString, [int]$page, [int]$itemPage) {
        return $this.SelectFromObject($value, $LikeString, "AND", $true, $page, $itemPage, $true);
    }
    [System.Collections.Generic.List[PSObject]]SelectFromObjectPaged($value, [bool]$LikeString, [string]$operator, [int]$page) {
        return $this.SelectFromObject($value, $LikeString, $operator, $true, $page, 100, $true);
    }
    [System.Collections.Generic.List[PSObject]]SelectFromObjectPaged($value, [bool]$LikeString, [string]$operator, [int]$page, [int]$itemPage) {
        return $this.SelectFromObject($value, $LikeString, $operator, $true, $page, $itemPage, $true);
    }
    [System.Collections.Generic.List[PSObject]]SelectFromObject($value) {
        return $this.SelectFromObject($value, $false, "AND", $false, 1, 100, $false)
    }
    [System.Collections.Generic.List[PSObject]]SelectFromObject($value, [bool]$LikeString) {
        return $this.SelectFromObject($value, $LikeString, "AND", $false, 1, 100, $False)
    }
    [System.Collections.Generic.List[PSObject]]SelectFromObject($value, [bool]$LikeString, [string]$operator , [bool]$Paged, [int] $page , [int]$QtdItemPage, [bool]$OrderBy) {
        [System.Type]$type = $value.GetType();
        $this.CreateTableIfNotExistsFromType($type);
        [System.Text.StringBuilder]$Query = [System.Text.StringBuilder]::new();
        [string]$SchemaTable = $type.Name;
        [System.ComponentModel.DataAnnotations.Schema.TableAttribute]$table = [System.Attribute]::GetCustomAttribute($type, [System.ComponentModel.DataAnnotations.Schema.TableAttribute]);
        if ($table) {
            if ($table.Schema) {
                $SchemaTable = "$($table.Schema)_$($table.Name)";
            }
            else {
                $SchemaTable = "$($table.Name)";
            }
        }
        $Query.Append("SELECT * FROM ").Append( $SchemaTable).Append(" ");
        $properties = $type.GetProperties();
        $flg_next = $false;
        $flg_where = $true;
        $pIdNmae = ($properties | Where-Object { $_.GetCustomAttributes($false) | Where-Object { $_.GetType() -eq [System.ComponentModel.DataAnnotations.KeyAttribute] } } | Select-Object -Property Name -First 1).Name

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

                if ($properties[$i].Name.ToLower().Contains("navigation")) {
                    $flg_next = $i -lt $properties.Length;
                    continue;
                }

                if ($flg_next) {
                    $Query.Append(" $operator ").Append(" ")
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
                elseif ($properties[$i].PropertyType.Name -eq "Boolean") {
                    $Query.Append($pNme).Append("=").Append($pValue);
                }
                else {
                    $Query.Append($pNme).Append("=").Append("'").Append($pValue).Append("'");
                }

                $flg_next = $true;
            }
            else {
                
                foreach ($item in $properties[$i].GetCustomAttributes($false)) {
                    if ($item.GetType() -ne [System.ComponentModel.DataAnnotations.RequiredAttribute] -and $item.GetType() -ne [System.ComponentModel.DataAnnotations.KeyAttribute]) {
                        if (-not $flg_where) {
                            $Query.Append(" $operator ").Append(" ").Append($pNme).Append(" IS NULL ");
                        }
                    }
                }

            }
        }

        if ($OrderBy) {
            $Query.Append(" ORDER BY $pIdNmae DESC");    
        }

        if ($Paged) {
            $offset = ($page - 1) * $QtdItemPage;
            $Query.Append(" LIMIT $offset,$QtdItemPage");    
        }



        $Query.Append(";");
        Write-Debug $Query.ToString()
        $results = ConvertTo-PscSqliteType -collection ($this.Execute($Query.ToString())) -type ($type) ;
        foreach ($result in $results) {
            for ($i = 0; $i -lt $properties.Count; $i++) {
                if ($properties[$i].PropertyType.IsClass -and $properties[$i].Name.ToLower().Contains("navigation")) {
                    $pname = $properties[$i].Name;
                    if ([System.Activator]::CreateInstance($properties[$i].PropertyType) -is [System.Collections.ICollection] -and $properties[$i].PropertyType.IsGenericType) {
                   
                        $InnerType = $properties[$i].PropertyType.GetGenericArguments();
                        if ($InnerType.Count -eq 1) {
                            $clsBase = [System.Activator]::CreateInstance($InnerType[0]);
                            ($clsBase).$pIdNmae = ($result.$pIdNmae);
                            $resultado = $this.SelectFromObject($clsBase)
                            ($result.$pname) = [System.Activator]::CreateInstance($properties[$i].PropertyType);
                            foreach ($item in $resultado) {
                                ($result.$pname).Add($item);
                            }
                        }                        
                    }
                    else {
    
                        ($result.$pname) = [System.Activator]::CreateInstance($properties[$i].PropertyType);
                        ($result.$pname).$pIdNmae = ($result.$pIdNmae);
                        $clsBase = ($result.$pname);
                        $resultado = $this.SelectFromObject($clsBase);
                        foreach ($item in $resultado) {
                            ($result.$pname) = ($item);
                            break;
                        }
                    }
                }
            }
        }
    

        return $results;
    }

    InsertFromObject($value) {
        [System.Type]$type = $value.GetType();
        $this.CreateTableIfNotExistsFromType($type);
        [System.Collections.Generic.List[PSObject]]$Navigations = [System.Collections.Generic.List[PSObject]]::new();

        [System.Text.StringBuilder]$Query = [System.Text.StringBuilder]::new();
        [string]$SchemaTable = $type.Name;
        [string]$idName = "";
        [System.ComponentModel.DataAnnotations.Schema.TableAttribute]$table = [System.Attribute]::GetCustomAttribute($type, [System.ComponentModel.DataAnnotations.Schema.TableAttribute]);
        if ($table) {
            if ($table.Schema) {
                $SchemaTable = "$($table.Schema)_$($table.Name)";
            }
            else {
                $SchemaTable = "$($table.Name)";
            }
        }
        $Query.Append("INSERT INTO ").Append($SchemaTable).Append(" (");
        $properties = $type.GetProperties();
        for ($i = 0; $i -lt $properties.Count; $i++) {
            #
            # Attribute?
            #
            [bool]$isID = $false;
            foreach ($item in $properties[$i].GetCustomAttributes($false)) {    
                if ($item.GetType() -eq [System.ComponentModel.DataAnnotations.KeyAttribute]) {
                    $idName = $properties[$i].Name;
                    $valueItem = $value.$idName;
                    $defaultValue = [System.Activator]::CreateInstance($properties[$i].PropertyType)
                    $isID = $valueItem -eq $defaultValue;
                    
                }
               
            }
            if ($properties[$i].PropertyType.IsClass -and $properties[$i].Name.ToLower().Contains("navigation")) {
                continue;
            }
           
            if (-not $isID ) {
                $Query.Append($properties[$i].Name);
                if ($i -lt $properties.Count - 1 -and -not ($properties[$i + 1].PropertyType.IsClass -and $properties[$i + 1].Name.ToLower().Contains("navigation"))) {
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
                    if ([string]::IsNullOrEmpty($value.$pname)) {
                        $Query.Append("NULL");
                    }
                    else {
                        $Query.Append("'").Append($value.$pname).Append("'");
                    }
                }
                elseif ($properties[$i].PropertyType.Name -eq "Double" -or $properties[$i].PropertyType.Name -eq "Single" -or $properties[$i].PropertyType.Name -eq "Decimal") {
                    $Query.Append(($value.$pname).ToString().Replace(",", "."));
                }
                elseif ($properties[$i].PropertyType.Name -eq "Boolean") {
                    $Query.Append([int]($value.$pname));
                }
                elseif ($properties[$i].PropertyType.Name -eq "DateTime" ) {
                    $Query.Append("'").Append(($value.$pname).ToString("yyyy-MM-dd HH:mm:ss")).Append("'");
                }
                elseif ($properties[$i].PropertyType.IsClass -and $properties[$i].Name.ToLower().Contains("navigation")) {
                    if ([System.Activator]::CreateInstance($properties[$i].PropertyType) -is [System.Collections.ICollection] -and $properties[$i].PropertyType.IsGenericType) {
                        $vlrs = ($value.$pname);
                        foreach ($vlr in $vlrs) {
                            $Navigations.Add($vlr);
                        }
                            
                    }
                    else {
                        $Navigations.Add(($value.$pname));
                    }
                }
                else {
                    #
                    # Nullable?
                    #

                    if ($null -ne [System.Nullable]::GetUnderlyingType($properties[$i].PropertyType)) {
                        $nlType = [System.Nullable]::GetUnderlyingType($properties[$i].PropertyType);
                        
                        if ($nlType.Name -eq "Int32" -or $nlType.Name -eq "Byte") {
                            $Query.Append($value.$pname);
                        }
                        elseif ($nlType.Name -eq "DateTime") {
                            if ($value.$pname) {
                                $Query.Append("'").Append(($value.$pname).ToString("yyyy-MM-dd HH:mm:ss")).Append("'");
                            }
                            else {
                                $Query.Append("NULL");
                            }
                            
                        }
                        elseif ($nlType.Name -eq "Double" -or $nlType.Name -eq "Single" -or $nlType.Name -eq "Decimal") {
                            $Query.Append(($value.$pname).ToString().Replace(",", "."));
                        }
                        elseif ($nlType.Name -eq "Boolean") {
                            $Query.Append([int]($value.$pname));
                        }
                        else {
                            $Query.Append("'").Append($value.$pname).Append("'");
                        }
                    }
                }


                if ($i -lt $properties.Count - 1 -and -not ($properties[$i + 1].PropertyType.IsClass -and $properties[$i + 1].Name.ToLower().Contains("navigation"))) {
                    $Query.Append(",")
                }
            }

        
        }
        $Query.Append(");");
        Write-Debug $Query.ToString();
        $this.ExecuteNonQuery($Query.ToString(), $true);

        $idInsert = $this.ExecuteScalar("select last_insert_rowid()");

        $value.$idName = $idInsert;
        if ($Navigations.Count -gt 0) {
            foreach ($navigationItem in $Navigations) {
                [System.Type]$type_navigation = $navigationItem.GetType();
                $properties_navigation = $type_navigation.GetProperties();

                for ($i = 0; $i -lt $properties_navigation.Count; $i++) {
                    foreach ($propertyItem in $properties_navigation[$i].GetCustomAttributes($false)) {    
                        if ($propertyItem.GetType() -eq [System.ComponentModel.DataAnnotations.Schema.ForeignKeyAttribute]) {
                            [string]$pnameNavigation = ([System.ComponentModel.DataAnnotations.Schema.ForeignKeyAttribute]$propertyItem).Name;
                            [string]$pnameProperty = $properties_navigation[$i].Name;
                            if ($pnameNavigation -eq $SchemaTable) {
                                $navigationItem.$pnameProperty = $idInsert;
                            }         
                        }
                    }
                }
                $this.InsertFromObject($navigationItem);
            }
        }
    }
    UpdateFromObject($value) {
        [System.Type]$type = $value.GetType();
        $this.CreateTableIfNotExistsFromType($type);
        [System.Text.StringBuilder]$Query = [System.Text.StringBuilder]::new();
        [string]$SchemaTable = $type.Name;
        [System.ComponentModel.DataAnnotations.Schema.TableAttribute]$table = [System.Attribute]::GetCustomAttribute($type, [System.ComponentModel.DataAnnotations.Schema.TableAttribute]);
        if ($table) {
            if ($table.Schema) {
                $SchemaTable = "$($table.Schema)_$($table.Name)";
            }
            else {
                $SchemaTable = "$($table.Name)";
            }
        }
        $Query.Append("UPDATE ").Append($SchemaTable).Append(" SET ");
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
                $pname = $properties[$i].Name;
                
      
                if ($flg_next) {
                    $Query.Append(",")
                    $flg_next = $false;
                }

                if ($properties[$i].PropertyType.Name -eq "Int32" -or $properties[$i].PropertyType.Name -eq "Byte") {
                    $Query.Append($pname).Append("=").Append($value.$pname);
                }
                elseif ($properties[$i].PropertyType.Name -eq "String") {
                    if ([string]::IsNullOrEmpty($value.$pname)) {
                        $Query.Append($pname).Append("=").Append("NULL");
                    }
                    else {
                        $Query.Append($pname).Append("=").Append("'").Append($value.$pname).Append("'");
                    }
                }
                elseif ($properties[$i].PropertyType.Name -eq "Double" -or $properties[$i].PropertyType.Name -eq "Single" -or $properties[$i].PropertyType.Name -eq "Decimal") {
                    $Query.Append($pname).Append("=").Append(($value.$pname).ToString().Replace(",", "."));
                }
                elseif ($properties[$i].PropertyType.Name -eq "Boolean") {
                    $Query.Append($pname).Append("=").Append([int]($value.$pname));
                }
                elseif ($properties[$i].PropertyType.Name -eq "DateTime" ) {
                    $Query.Append($pname).Append("=").Append("'").Append(($value.$pname).ToString("yyyy-MM-dd HH:mm:ss")).Append("'");
                }
                elseif ($properties[$i].PropertyType.IsClass -and $properties[$i].Name.ToLower().Contains("navigation")) {
                    if ([System.Activator]::CreateInstance($properties[$i].PropertyType) -is [System.Collections.ICollection] -and $properties[$i].PropertyType.IsGenericType) {
                        $vlrs = ($value.$pname);
                        foreach ($vlr in $vlrs) {
                            $this.UpdateFromObject($vlr);
                        }
                            
                    }
                    else {
                        $this.UpdateFromObject(($value.$pname));
                    }
                }
                else {
                    #
                    # Nullable?
                    #

                    if ($null -ne [System.Nullable]::GetUnderlyingType($properties[$i].PropertyType)) {
                        $nlType = [System.Nullable]::GetUnderlyingType($properties[$i].PropertyType);
                        
                        if ($nlType.Name -eq "Int32" -or $nlType.Name -eq "Byte") {
                            $Query.Append($pname).Append("=").Append($value.$pname);
                        }
                        elseif ($nlType.Name -eq "DateTime") {
                            if ($value.$pname) {
                                $Query.Append($pname).Append("=").Append("'").Append(($value.$pname).ToString("yyyy-MM-dd HH:mm:ss")).Append("'");
                            }
                            else {
                                $Query.Append($pname).Append("=").Append("NULL");
                            }
                            
                        }
                        elseif ($nlType.Name -eq "Double" -or $nlType.Name -eq "Single" -or $nlType.Name -eq "Decimal") {
                            $Query.Append($pname).Append("=").Append(($value.$pname).ToString().Replace(",", "."));
                        }
                        elseif ($nlType.Name -eq "Boolean") {
                            $Query.Append($pname).Append("=").Append([int]($value.$pname));
                        }
                        else {
                            $Query.Append($pname).Append("=").Append("'").Append($value.$pname).Append("'");
                        }
                    }
                }
                if ($properties.Count - 1 -gt $i -and -not ($properties[$i + 1].PropertyType.IsClass -and $properties[$i + 1].Name.ToLower().Contains("navigation"))) {
                    $flg_next = $true;
                }
                else {
                    $flg_next = $false;
                }
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
                $pname = $properties[$i].Name;
                
                if ($flg_next) {
                    $Query.Append(" AND ")
                    $flg_next = $false;
                }
                if ($properties[$i].PropertyType.Name -eq "Int32" -or $properties[$i].PropertyType.Name -eq "Byte") {
                    $Query.Append($pname).Append("=").Append($value.$pname);
                }
                elseif ($properties[$i].PropertyType.Name -eq "String") {
                    if ([string]::IsNullOrEmpty($value.$pname)) {
                        $Query.Append($pname).Append(" IS ").Append("NULL");
                    }
                    else {
                        $Query.Append($pname).Append("=").Append("'").Append($value.$pname).Append("'");
                    }
                }
                elseif ($properties[$i].PropertyType.Name -eq "Double" -or $properties[$i].PropertyType.Name -eq "Single" -or $properties[$i].PropertyType.Name -eq "Decimal") {
                    $Query.Append($pname).Append("=").Append(($value.$pname).ToString().Replace(",", "."));
                }
                elseif ($properties[$i].PropertyType.Name -eq "Boolean") {
                    $Query.Append($pname).Append("=").Append(($value.$pname));
                }
                elseif ($properties[$i].PropertyType.Name -eq "DateTime" ) {
                    $Query.Append($pname).Append("=").Append("'").Append(($value.$pname).ToString("yyyy-MM-dd HH:mm:ss")).Append("'");
                }
                else {
                    #
                    # Nullable?
                    #

                    if ($null -ne [System.Nullable]::GetUnderlyingType($properties[$i].PropertyType)) {
                        $nlType = [System.Nullable]::GetUnderlyingType($properties[$i].PropertyType);
                        
                        if ($nlType.Name -eq "Int32" -or $nlType.Name -eq "Byte") {
                            $Query.Append($pname).Append("=").Append($value.$pname);
                        }
                        elseif ($nlType.Name -eq "DateTime") {
                            if ($value.$pname) {
                                $Query.Append($pname).Append("=").Append("'").Append(($value.$pname).ToString("yyyy-MM-dd HH:mm:ss")).Append("'");
                            }
                            else {
                                $Query.Append($pname).Append(" IS ").Append("NULL");
                            }
                            
                        }
                        elseif ($nlType.Name -eq "Double" -or $nlType.Name -eq "Single" -or $nlType.Name -eq "Decimal") {
                            $Query.Append($pname).Append("=").Append(($value.$pname).ToString().Replace(",", "."));
                        }
                        elseif ($nlType.Name -eq "Boolean") {
                            $Query.Append($pname).Append("=").Append(($value.$pname));
                        }
                        else {
                            $Query.Append($pname).Append("=").Append("'").Append($value.$pname).Append("'");
                        }
                    }
                }

                $flg_next = $true;
            }

            
        }
        $Query.Append(";");
        Write-Debug $Query.ToString();
        $this.ExecuteNonQuery($Query.ToString());
    }
    DeleteFromObject($value) {
        [System.Type]$type = $value.GetType();
        $this.CreateTableIfNotExistsFromType($type);
        [System.Text.StringBuilder]$Query = [System.Text.StringBuilder]::new();
        [string]$SchemaTable = $type.Name;
        [System.ComponentModel.DataAnnotations.Schema.TableAttribute]$table = [System.Attribute]::GetCustomAttribute($type, [System.ComponentModel.DataAnnotations.Schema.TableAttribute]);
        if ($table) {
            if ($table.Schema) {
                $SchemaTable = "$($table.Schema)_$($table.Name)";
            }
            else {
                $SchemaTable = "$($table.Name)";
            }
        }
        $Query.Append("DELETE FROM ").Append($SchemaTable);
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

            if ($properties[$i].PropertyType.IsClass -and $properties[$i].Name.ToLower().Contains("navigation")) {
                $pname = $properties[$i].Name;

                if ([System.Activator]::CreateInstance($properties[$i].PropertyType) -is [System.Collections.ICollection] -and $properties[$i].PropertyType.IsGenericType) {
                    $vlrs = ($value.$pname);
                    foreach ($vlr in $vlrs) {
                        $this.DeleteFromObject($vlr);
                    }
                        
                }
                else {
                    $this.DeleteFromObject(($value.$pname));
                }
            }
            
        }
        $Query.Append(";");
        Write-Debug $Query.ToString();
        $this.ExecuteNonQuery($Query.ToString());
    }
    [bool]ExistsFromObject($value) {
        return $this.SelectFromObject($value).Count -ne 0;
    }
}




function ConvertTo-PscSqliteType {
    param (
        # Lista ou objeto a ser convertido
        [Parameter(Mandatory = $true, Position = 0)]
        $collection,
        # Tipo a ser convertido
        [Parameter(Mandatory = $true, Position = 1)]
        [System.Type]
        $type
    )

    begin {
        $newCollection = [System.Collections.ArrayList]::new();
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

