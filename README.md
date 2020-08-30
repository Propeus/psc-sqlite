## Descrição
Este projeto tem como objetivo facilitar o uso do SQLite no Powershell.

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

Criar tabela a partir do objeto
```powershell
Import-Module "psc-sqlite.psd1" -Force -Global
$database = New-PscSqlite -PathFile "database.sqlite" #Cria no mesmo caminho onde está a instancia do PowerShell

class TEST{
    [System.ComponentModel.DataAnnotations.KeyAttribute()][System.ComponentModel.DataAnnotations.RequiredAttribute()][int]$ID 
    [System.ComponentModel.DataAnnotations.RequiredAttribute()][string]$string 
    [float]$float 
    [bool]$bool 
    [decimal]$decimal
    [double]$double
    $any
}

# INFO
# Cria uma tabela baseado no tipo especificado.
# AVISO
# Caso já exista uma tabela, o SQLite exibirá uma mensagem de erro
$DB.CreateTableFromType([TEST])

# INFO
# Cria uma tabela baseado no tipo especificado e adiciona o autoincremento na propriedade que possua o atributo 'KeyAttribute'
$DB.CreateTableFromType([TEST],$true,$false,$false)

# INFO
# Cria uma tabela baseado no tipo especificado excluindo a atual caso exista.
# Adiciona o autoincremento na propriedade que possua o atributo 'KeyAttribute'
$DB.CreateTableFromType([TEST],$true,$true,$false)

# INFO
# Cria uma tabela baseado no tipo especificado caso não exista.
$DB.CreateTableFromType([TEST],$true,$false,$true)

# INFO
# Cria uma tabela caso nao exista.
$DB.CreateTableIfNotExistsFromType([TEST])

# INFO
# Cria uma nova tabela independente se existir ou não.
# AVISO
# Caso já exista uma tabela, será dropado a tabela antiga para criar a nova
$DB.RecreateTableFromType([TEST])
```

Inserir objeto na tabela 
```powershell
Import-Module "psc-sqlite.psd1" -Force -Global
$database = New-PscSqlite -PathFile "database.sqlite" #Cria no mesmo caminho onde está a instancia do PowerShell

class TEST{
    [System.ComponentModel.DataAnnotations.KeyAttribute()][System.ComponentModel.DataAnnotations.RequiredAttribute()][int]$ID 
    [System.ComponentModel.DataAnnotations.RequiredAttribute()][string]$string 
    [float]$float 
    [bool]$bool 
    [decimal]$decimal
    [double]$double
    $any
}

$typeTeste = [TEST]::new();
$typeTeste.string = "teste inserir objeto"
$typeTeste.float = .1
$typeTeste.bool = $true
$typeTeste.decimal = .56
$typeTeste.double = .566


# INFO
# Caso a tabela não exista, será criado um com o nome do tipo 
# e suas colunas serão criados e tipados de acordo com as propriedades da classe.
$DB.InsertFromType($typeTeste)

# AVISO
# O resultado vem um uma [System.Collections.Generic.List[PSObject]]
# por este motivo alguns valores podem vir em um formato difente.
# Exemplo: $true -> 1; $false -> 0
$result = $DB.Execute("SELECT * FROM TEST") 

# INFO
# Para converter o [System.Collections.Generic.List[PSObject]]
# para o tipo desejado basta executar o comando ConvertTo-PscSqliteType <colecao> ([<tipo>]).
ConvertTo-PscSqliteType $result ([TEST])
```