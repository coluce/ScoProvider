# Comparação: Firebird vs SQLite

Este documento compara as implementações do ScoProvider para Firebird e SQLite.

## 📊 Tabela de Compatibilidade

| Funcionalidade | Firebird | SQLite | Observações |
|----------------|----------|--------|-------------|
| **Conexão** | ✅ | ✅ | SQLite apenas precisa do arquivo |
| **Criação de Tabelas** | ✅ | ✅ | SQLite tem limitações no ALTER TABLE |
| **Tipos de Dados** | ✅ | ⚠️ | Mapeamento automático de tipos |
| **Chaves Primárias** | ✅ | ✅ | Suporte completo |
| **Foreign Keys** | ✅ | ⚠️ | SQLite: apenas na criação da tabela |
| **Índices** | ✅ | ✅ | Suporte completo |
| **Triggers** | ✅ | ✅ | Sintaxe pode diferir |
| **Sequences/Generators** | ✅ | ❌ | SQLite usa AUTOINCREMENT |
| **Character Sets** | ✅ | ❌ | SQLite sempre UTF-8 |
| **Transações** | ✅ | ✅ | Suporte completo |
| **BLOB/TEXT** | ✅ | ✅ | Tipos mapeados automaticamente |
| **Metadados** | ✅ | ✅ | Via PRAGMA no SQLite |

## 🔄 Migração de Firebird para SQLite

### 1. Alteração do Provider
```delphi
// Antes (Firebird)
LDatabase := TScoProvider.Firebird;
LDatabase.DatabaseInfo.Server := 'localhost';
LDatabase.DatabaseInfo.Port := 3050;
LDatabase.DatabaseInfo.FileName := 'database.fdb';
LDatabase.DatabaseInfo.UserName := 'SYSDBA';
LDatabase.DatabaseInfo.Password := 'masterkey';

// Depois (SQLite)
LDatabase := TScoProvider.SQLite;
LDatabase.DatabaseInfo.FileName := 'database.db';
// Apenas o arquivo é necessário
```

### 2. Ajustes nos Tipos de Dados

```delphi
// Firebird
LTable.Fields.AddStringField(1, 'NAME', 100, 'UTF8'); // Character set é usado

// SQLite (equivalente)
LTable.Fields.AddStringField(1, 'NAME', 100); // Character set é ignorado
```

### 3. Sequences → AUTOINCREMENT

```delphi
// Firebird (com sequence/generator)
// CREATE GENERATOR GEN_USUARIO_ID;
// CREATE TRIGGER TRG_USUARIO_BI FOR USUARIO
//   BEFORE INSERT AS BEGIN
//     NEW.ID = GEN_ID(GEN_USUARIO_ID, 1);
//   END;

// SQLite (com AUTOINCREMENT)
LTable.Fields.AddIntegerField(1, 'ID').PrimaryKey(True);
// Automaticamente será INTEGER PRIMARY KEY AUTOINCREMENT
```

### 4. Foreign Keys - Cuidados Especiais

```delphi
// Firebird - funciona sempre
LDatabase.CreateTable(LParentTable);
LDatabase.CreateTable(LChildTable); // Com FK

// SQLite - requer cuidado
LDatabase.CreateTable(LParentTable, True);  // Criar primeiro
LDatabase.CreateTable(LChildTable, True);   // FK só funciona se criar junto
```

## ⚠️ Pontos de Atenção na Migração

### 1. Scripts SQL Específicos
Alguns comandos SQL precisam ser adaptados:

**Firebird:**
```sql
SELECT RDB$FIELD_NAME FROM RDB$RELATION_FIELDS 
WHERE RDB$RELATION_NAME = 'TABELA'
```

**SQLite:**
```sql
PRAGMA table_info('TABELA')
```

### 2. Tipos de Dados
| Firebird | SQLite | Observação |
|----------|--------|------------|
| `VARCHAR(100) CHARACTER SET UTF8` | `VARCHAR(100)` | Character set removido |
| `NUMERIC(15,2)` | `REAL` | Pode haver perda de precisão |
| `BLOB SUB_TYPE 1` | `TEXT` | Texto longo |
| `BLOB SUB_TYPE 0` | `BLOB` | Dados binários |
| `TIMESTAMP` | `DATETIME` | Formato pode diferir |

### 3. Limitações do ALTER TABLE
```delphi
// ❌ Pode falhar no SQLite
LDatabase.CreateTable(LExistingTable, False); // Adicionar campos

// ✅ Sempre funciona
LDatabase.CreateTable(LTable, True); // Recriar tabela
```

## 🎯 Recomendações de Uso

### Use Firebird quando:
- Precisar de sequences/generators
- Tiver foreign keys complexas
- Precisar de character sets específicos
- Aplicação multi-usuário com muitas transações concorrentes
- Precisar de stored procedures e triggers avançados

### Use SQLite quando:
- Aplicação desktop/móvel single-user
- Necessitar de deployment simples (arquivo único)
- Performance em leitura for prioridade
- Banco incorporado (embedded)
- Prototipagem rápida

## 🚀 Exemplo de Código Genérico

```delphi
// Código que funciona com ambos os provedores
procedure CreateUserTable(AProvider: IProviderDatabase);
var
  LTable: ITable;
begin
  LTable := TStructureDomain.Table;
  LTable.Name('USUARIOS');
  
  // Campos compatíveis com ambos
  LTable.Fields
    .AddIntegerField(1, 'ID')
      .PrimaryKey(True)
      .NotNull(True);
  LTable.Fields.AddStringField(2, 'NOME', 100);
  LTable.Fields.AddStringField(3, 'EMAIL', 150);
  LTable.Fields.AddBooleanField(4, 'ATIVO');
  LTable.Fields.AddDateTimeField(5, 'CRIADO_EM');
  
  // Criar tabela (compatível com ambos)
  AProvider.CreateTable(LTable, True);
end;

// Uso
var
  LFirebird, LSQLite: IProviderDatabase;
begin
  // Firebird
  LFirebird := TScoProvider.Firebird;
  LFirebird.DatabaseInfo.FileName := 'app.fdb';
  CreateUserTable(LFirebird);
  
  // SQLite  
  LSQLite := TScoProvider.SQLite;
  LSQLite.DatabaseInfo.FileName := 'app.db';
  CreateUserTable(LSQLite);
end;
```

## 📈 Performance

### Firebird
- ✅ Melhor para escritas concorrentes
- ✅ Transações ACID robustas
- ✅ Otimizador de consultas avançado
- ⚠️ Overhead de servidor

### SQLite
- ✅ Excelente para leituras
- ✅ Zero configuração
- ✅ Muito rápido para dados locais
- ⚠️ Limitações em concorrência
- ⚠️ Lock de tabela inteira em escritas

## 🔧 Debugging e Troubleshooting

### Logs de Conexão
```delphi
// Ver string de conexão
Writeln('Firebird: ', LFirebird.ConnectionString);
// Output: Database=app.fdb;User_Name=SYSDBA;Password=masterkey;Server=localhost...

Writeln('SQLite: ', LSQLite.ConnectionString);  
// Output: Database=app.db;DriverID=SQLite
```

### Verificar Recursos
```delphi
// Testar se sequences são suportadas
try
  var LSeq := TStringList.Create;
  try
    LDatabase.FillSequences(LSeq);
    Writeln('Sequences suportadas: ', LSeq.Count);
  finally
    LSeq.Free;
  end;
except
  on E: Exception do
    Writeln('Sequences não suportadas: ', E.Message);
end;
```