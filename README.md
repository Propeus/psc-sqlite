## Descrição
Este projeto tem como objetivo facilitar o usop do SQLite usando o Powershell.

## Exemplos
Criar um banco de dados em memoria
```powershell
Import-Module "psc-sqlite.psd1" -Force -Global
$database = New-PscSqlite
$database.ExecuteNonQuery('CREATE TABLE IF NOT EXISTS TEST( ID INT NOT NULL, NME TEXT NOT NULL)');
```

Criar um banco de dados em disco
```powershell
Import-Module "psc-sqlite.psd1" -Force -Global
$database = New-PscSqlite -PathFile "database.sqlite" #Cria no mesmo caminho onde está a instancia do PowerShell
$database.ExecuteNonQuery('CREATE TABLE IF NOT EXISTS TEST( ID INT NOT NULL, NME TEXT NOT NULL)');
```

Executar query com resultado retornando o reader
```powershell
Import-Module "psc-sqlite.psd1" -Force -Global
$database = New-PscSqlite -PathFile "database.sqlite" #Cria no mesmo caminho onde está a instancia do PowerShell
$reader = $database.ExecuteReader('SELECT * FROM TEST');
while($Reader.Read()){
    for ([int]$i = 0; $i -lt $reader.FieldCount; $i++) 
    {
        Write-Host $reader.GetValue($i);
    }  
}
```

Executar query com resultado retornando a tabela como objeto
```powershell
Import-Module "psc-sqlite.psd1" -Force -Global
$database = New-PscSqlite -PathFile "database.sqlite" #Cria no mesmo caminho onde está a instancia do PowerShell
$result = $database.Execute('SELECT * FROM TEST');
Write-Host $result;
```