// =====================================================================
// BI de Gestão de Pessoas (CGGP/SPOA – MDA)
// Exemplos simplificados do ETL em camadas no Power Query (M).
// Camadas: originais (sem carga) -> stg_ (limpeza) -> aux_ (de-para) -> dimensões e fatos
// =====================================================================

// stg_Funcoes: padronização dos códigos de função e da situação do posto
let
    Fonte = Planilha_CargosFuncoes_Original,
    Texto = Table.TransformColumns(Fonte, {
        {"Unidade", each Text.Upper(Text.Trim(_)), type text},
        {"CodigoFuncao", each if _ = null then null else Text.Upper(Text.Remove(_, {" ", "."})), type text},
        {"Situacao", each Text.Proper(Text.Trim(_)), type text}
    }),
    // Postos sem código de função ficam marcados para conferência em vez de sumirem
    Marcados = Table.AddColumn(Texto, "SemCodigo", each [CodigoFuncao] = null, type logical),
    Situacao = Table.ReplaceValue(Marcados, "Vacante", "Vago", Replacer.ReplaceText, {"Situacao"})
in
    Situacao

// aux_Unidades: de-para de siglas inconsistentes, SIORG duplicado e unidades sem Macro
let
    Fonte = stg_Unidades,
    DePara = Table.NestedJoin(Fonte, {"Sigla"}, aux_DeParaSiglas, {"SiglaOriginal"}, "dp", JoinKind.LeftOuter),
    Expandido = Table.ExpandTableColumn(DePara, "dp", {"SiglaCorreta"}),
    Sigla = Table.AddColumn(Expandido, "SiglaFinal", each [SiglaCorreta] ?? [Sigla], type text),
    SemDuplicado = Table.Distinct(Sigla, {"CodigoSIORG"}),
    Macro = Table.AddColumn(SemDuplicado, "MacroFinal", each [Macro] ?? "A CLASSIFICAR", type text)
in
    Macro

// Faixa etária com coluna de ordem criada no Power Query
// (permite "Classificar por coluna" sem criar dependência circular no modelo)
let
    Fonte = stg_Servidores,
    Faixa = Table.AddColumn(Fonte, "FaixaEtaria", each
        if [Idade] <= 30 then "ATÉ 30 ANOS"
        else if [Idade] <= 45 then "31-45 ANOS"
        else if [Idade] <= 60 then "46-60 ANOS"
        else "61+ ANOS", type text),
    Ordem = Table.AddColumn(Faixa, "FaixaOrdem", each
        if [Idade] <= 30 then 1 else if [Idade] <= 45 then 2 else if [Idade] <= 60 then 3 else 4, Int64.Type)
in
    Ordem

// Data de atualização no fuso de Brasília
let
    Agora = DateTimeZone.SwitchZone(DateTimeZone.UtcNow(), -3),
    Tabela = #table(type table [Atualizado = datetime], {{DateTimeZone.RemoveZone(Agora)}})
in
    Tabela
