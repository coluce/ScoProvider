# ScoProvider - Implementação SQLite

Esta é a implementação do ScoProvider para bancos de dados SQLite.

## 🔧 Configuração

```delphi
uses 
  Sco.Provider;
var
  LDatabase: IProviderDatabase;
begin
  LDatabase := TScoProvider.SQLite;
  LDatabase.DatabaseInfo.FileName := 'C:\MyProject\database.db';
end;
```

## 📊 Tipos de Dados Suportados

O SQLite tem um sistema de tipos mais flexível que o Firebird. A implementação mapeia os tipos da seguinte forma:

| Tipo Firebird | Tipo SQLite | Observações |
|---------------|-------------|-------------|
| INTEGER | INTEGER | Suporte completo |
| VARCHAR(n) | VARCHAR(n) ou TEXT | Suporte completo |
| CHAR(n) | VARCHAR(n) | Convertido para VARCHAR |
| NUMERIC(p,s) | REAL | Precisão pode ser diferente |
| TIMESTAMP | DATETIME | Suporte completo |
| BOOLEAN | BOOLEAN | Suporte completo |
| BLOB SUB_TYPE 0 | BLOB | Dados binários |
| BLOB SUB_TYPE TEXT | TEXT | Texto longo |

## ⚠️ Limitações e Recursos Não Suportados

### 1. Sequences/Generators
```delphi
// ❌ Não suportado - gera exceção
LDatabase.FillSequences(LList); 
// Exceção: "SQLite não suporta sequences. Use AUTOINCREMENT em campos INTEGER PRIMARY KEY."
```

**Alternativa:** Use `AUTOINCREMENT` em campos `INTEGER PRIMARY KEY`:
```delphi
// ✅ Alternativa recomendada
LTable.Fields.AddIntegerField(1, 'ID').PrimaryKey(True); // Será criado com AUTOINCREMENT
```

### 2. Character Sets
```delphi
// ⚠️ Ignorado silenciosamente
LField.CharacterSet('UTF8'); // SQLite sempre usa UTF-8
```

### 3. ALTER TABLE Limitações
O SQLite tem limitações significativas para alteração de estruturas de tabela:

```delphi
// ⚠️ Pode falhar em cenários complexos
LDatabase.CreateTable(LTable, False); // Adicionar campos em tabela existente
```

**Problemas conhecidos:**
- Não é possível adicionar campos NOT NULL sem valor padrão
- Não é possível modificar ou remover colunas facilmente
- Foreign keys não podem ser adicionadas após criação da tabela

**Solução:** Sempre use `ADropIfExists = True` quando possível:
```delphi
LDatabase.CreateTable(LTable, True); // ✅ Recomendado
```

### 4. Foreign Keys
```delphi
// ⚠️ Funciona apenas na criação da tabela
LTable.ForeignKeys.AddReference(LForeignKey);
LDatabase.CreateTable(LTable, True); // ✅ OK na criação

// ❌ Pode falhar em tabelas existentes
LDatabase.CreateTable(LExistingTable, False); // Foreign keys podem não ser adicionadas
```

## 🎯 Recursos Específicos do SQLite

### 1. PRAGMA Commands
```delphi
// Habilitar foreign keys (feito automaticamente)
LDatabase.SetSQL('PRAGMA foreign_keys = ON').Execute;

// Verificar informações da tabela
LDatabase.SetSQL('PRAGMA table_info(MinhaTabela)').Open;
```

### 2. Transações
```delphi
// ✅ Suporte completo
LDatabase.StartTransaction;
try
  // Operações...
  LDatabase.Commit;
except
  LDatabase.Rollback;
end;
```

### 3. Consultas de Metadados
```delphi
// ✅ Totalmente suportado
LDatabase.FillTableNames(LTables);
LDatabase.FillFieldNames('MinhaTabela', LFields);
LDatabase.FillPrimaryKeys('MinhaTabela', LPrimaryKeys);
LDatabase.FillForeignKeys('MinhaTabela', LForeignKeys);
LDatabase.FillIndexNames('MinhaTabela', LIndexes);
LDatabase.FillTriggers('MinhaTabela', LTriggers);
```

## 📝 Exemplo Completo

```delphi
program SQLiteExample;

uses
  Sco.Provider;

var
  LDatabase: IProviderDatabase;
  LTable: ITable;
begin
  // Configurar SQLite
  LDatabase := TScoProvider.SQLite;
  LDatabase.DatabaseInfo.FileName := 'exemplo.db';

  // Criar tabela
  LTable := TStructureDomain.Table.Name('USUARIOS');
  LTable.Fields
    .AddIntegerField(1, 'ID')
      .PrimaryKey(True)
      .NotNull(True);
  LTable.Fields.AddStringField(2, 'NOME', 100);
  LTable.Fields.AddBooleanField(3, 'ATIVO');

  // Criar no banco
  LDatabase.CreateTable(LTable, True);

  // Inserir dados
  LDatabase
    .Clear
    .SetSQL('INSERT INTO USUARIOS (NOME, ATIVO) VALUES (?, ?)')
    .SetStringParam('P1', 'João')
    .SetBooleanParam('P2', True)
    .Execute;
end.
```

## 🔍 Diagnóstico de Problemas

### Erro: "table already exists"
```delphi
// Solução: usar drop se existir
LDatabase.CreateTable(LTable, True);
```

### Erro: "Cannot add a NOT NULL column with default value NULL"
```delphi
// Problema: tentativa de adicionar campo NOT NULL em tabela existente
// Solução: recriar a tabela ou tornar o campo nullable
LField.NotNull(False); // ou
LDatabase.CreateTable(LTable, True);
```

### Foreign Keys não funcionam
```delphi
// Verificar se estão habilitadas
LDatabase.SetSQL('PRAGMA foreign_keys').Open;
// Deve retornar 1, senão executar:
LDatabase.SetSQL('PRAGMA foreign_keys = ON').Execute;
```

## 📚 Referências

- [SQLite Documentation](https://www.sqlite.org/docs.html)
- [SQLite Data Types](https://www.sqlite.org/datatype3.html)
- [SQLite ALTER TABLE](https://www.sqlite.org/lang_altertable.html)
- [SQLite Foreign Keys](https://www.sqlite.org/foreignkeys.html)