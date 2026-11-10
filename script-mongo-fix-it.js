// Selecionar o banco de dados
//use zeladoria_fixit;

// Limpeza prévia
db.ocorrencias_urbanas.drop();
db.usuarios_cidadaos.drop();

// Criação explícita das coleções
db.createCollection("usuarios_cidadaos");
db.createCollection("ocorrencias_urbanas");

// Criação de índice geoespacial 2dsphere obrigatório para consultas espaciais
db.ocorrencias_urbanas.createIndex({ localizacao: "2dsphere" });
db.ocorrencias_urbanas.createIndex({ status: 1, categoria: 1 });

// Inserção na collection: usuarios_cidadaos (3 documentos)
db.usuarios_cidadaos.insertMany([
  {
    _id: ObjectId("655100000000000000000001"),
    nome: "Carlos Mendes",
    email: "carlos.mendes@email.com",
    cpf: "111.222.333-44",
    telefone: "11988887777",
    reputacao_score: 95,
    data_cadastro: new Date("2026-01-10T10:00:00Z")
  },
  {
    _id: ObjectId("655100000000000000000002"),
    nome: "Mariana Silveira",
    email: "mariana.silva@email.com",
    cpf: "222.333.444-55",
    telefone: "11977776666",
    reputacao_score: 88,
    data_cadastro: new Date("2026-02-15T14:30:00Z")
  },
  {
    _id: ObjectId("655100000000000000000003"),
    nome: "Fiscal João Rocha",
    email: "joao.fiscal@sp.gov.br",
    cpf: "333.444.555-66",
    telefone: "11966665555",
    reputacao_score: 100,
    data_cadastro: new Date("2026-01-01T08:00:00Z")
  }
]);

// Inserção na collection: ocorrencias_urbanas (8 documentos com GeoJSON e embedded data)
// Totalizando 11 documentos inseridos (atende ao requisito de no mínimo 10)
db.ocorrencias_urbanas.insertMany([
  {
    _id: ObjectId("655200000000000000000001"),
    id_oracle_ref: 1,
    id_usuario_referencia: ObjectId("655100000000000000000001"),
    categoria: "BURACO_ASFALTO",
    descricao: "Cratera funda na faixa direita da via",
    bairro: "Bela Vista",
    localizacao: {
      type: "Point",
      coordinates: [-46.655981, -23.561684] // [Longitude, Latitude]
    },
    status: "CONCLUIDO",
    gravidade: "ALTA",
    ia_analise: {
      confianca_deteccao: 0.94,
      classe_predita: "buraco_asfalto",
      parecer_llm: "Risco iminente de dano aos eixos veiculares e acidentes com motociclistas."
    },
    ordem_servico: {
      equipe: "Equipe Pavimentação Centro",
      custo_reparo: 1250.00,
      data_fechamento: new Date("2026-11-01T16:00:00Z")
    },
    data_abertura: new Date("2026-10-15T09:30:00Z")
  },
  {
    _id: ObjectId("655200000000000000000002"),
    id_oracle_ref: 2,
    id_usuario_referencia: ObjectId("655100000000000000000001"),
    categoria: "ILUMINACAO_PUBLICA",
    descricao: "Poste com lâmpada queimada há duas semanas",
    bairro: "Bela Vista",
    localizacao: {
      type: "Point",
      coordinates: [-46.654300, -23.562100]
    },
    status: "ABERTO",
    gravidade: "URGENTE", // escalada pela rotina
    ia_analise: {
      confianca_deteccao: 0.89,
      classe_predita: "iluminacao_apagada",
      parecer_llm: "Trecho escuro facilitando ocorrências de insegurança pública."
    },
    data_abertura: new Date("2026-09-25T20:15:00Z")
  },
  {
    _id: ObjectId("655200000000000000000003"),
    id_oracle_ref: 3,
    id_usuario_referencia: ObjectId("655100000000000000000002"),
    categoria: "BUEIRO_ENTUPIDO",
    descricao: "Bueiro coberto de entulho gerando alagamento",
    bairro: "Pinheiros",
    localizacao: {
      type: "Point",
      coordinates: [-46.691230, -23.567890]
    },
    status: "EM_EXECUCAO",
    gravidade: "URGENTE",
    ia_analise: {
      confianca_deteccao: 0.96,
      classe_predita: "bueiro_entupido",
      parecer_llm: "Obstrução de 80% do fluxo pluvial em ponto de declive."
    },
    data_abertura: new Date("2026-11-04T11:00:00Z")
  },
  {
    _id: ObjectId("655200000000000000000004"),
    id_oracle_ref: 4,
    id_usuario_referencia: ObjectId("655100000000000000000002"),
    categoria: "DESCARTE_IRREGULAR",
    descricao: "Móveis velhos e entulho na calçada",
    bairro: "Pinheiros",
    localizacao: {
      type: "Point",
      coordinates: [-46.692000, -23.568100]
    },
    status: "ABERTO",
    gravidade: "MEDIA",
    ia_analise: {
      confianca_deteccao: 0.82,
      classe_predita: "descarte_irregular",
      parecer_llm: "Bloqueio parcial de rota acessível para pedestres."
    },
    data_abertura: new Date("2026-10-28T14:40:00Z")
  },
  {
    _id: ObjectId("655200000000000000000005"),
    categoria: "BURACO_ASFALTO",
    descricao: "Afundamento de pista próximo à faixa de pedestres",
    bairro: "Bela Vista",
    localizacao: {
      type: "Point",
      coordinates: [-46.655100, -23.561900]
    },
    status: "ABERTO",
    gravidade: "MEDIA",
    data_abertura: new Date("2026-11-05T08:10:00Z")
  },
  {
    _id: ObjectId("655200000000000000000006"),
    categoria: "ILUMINACAO_PUBLICA",
    descricao: "Fiação solta faíscando no poste",
    bairro: "Pinheiros",
    localizacao: {
      type: "Point",
      coordinates: [-46.690500, -23.567100]
    },
    status: "CONCLUIDO",
    gravidade: "URGENTE",
    ordem_servico: {
      equipe: "Equipe Elétrica Manutenção",
      custo_reparo: 450.00,
      data_fechamento: new Date("2026-11-06T18:00:00Z")
    },
    data_abertura: new Date("2026-11-05T19:20:00Z")
  },
  {
    _id: ObjectId("655200000000000000000007"),
    categoria: "BURACO_ASFALTO",
    descricao: "Buraco com água acumulada impedindo tráfego",
    bairro: "Pinheiros",
    localizacao: {
      type: "Point",
      coordinates: [-46.691800, -23.567950]
    },
    status: "ABERTO",
    gravidade: "ALTA",
    data_abertura: new Date("2026-11-06T12:00:00Z")
  },
  {
    _id: ObjectId("655200000000000000000008"),
    categoria: "DESCARTE_IRREGULAR",
    descricao: "Restos de demolição jogados no canteiro central",
    bairro: "Bela Vista",
    localizacao: {
      type: "Point",
      coordinates: [-46.656500, -23.561200]
    },
    status: "CONCLUIDO",
    gravidade: "MEDIA",
    ordem_servico: {
      equipe: "Limpeza Urbana Centro",
      custo_reparo: 800.00,
      data_fechamento: new Date("2026-11-07T14:00:00Z")
    },
    data_abertura: new Date("2026-11-02T10:00:00Z")
  }
]);

//relatorio 1
use("zeladorio_fixit")
db.ocorrencias_urbanas.aggregate([
  { $group: { _id: { categoria: "$categoria", status: "$status" }, total: { $sum: 1 } } },
  { $sort: { "_id.categoria": 1 } }
]);

//relatorio 2
use("zeladorio_fixit")
db.ocorrencias_urbanas.find(
  { gravidade: { $in: ["ALTA", "URGENTE"] }, status: { $ne: "CONCLUIDO" } },
  { categoria: 1, bairro: 1, gravidade: 1, data_abertura: 1 }
);

//relatorio 3
use("zeladoria_fixit")
db.ocorrencias_urbanas.find({
  localizacao: {
    $near: {
      $geometry: { type: "Point", coordinates: [-46.655981, -23.561684] },
      $maxDistance: 1000
    }
  }
}, { categoria: 1, bairro: 1, status: 1, localizacao: 1 });