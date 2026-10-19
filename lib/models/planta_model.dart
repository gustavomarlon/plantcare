import 'package:cloud_firestore/cloud_firestore.dart';

class PlantaModel {
  final String id;
  final String nome;
  final String especie;
  final String? fotoUrl;
  final int intervaloRegaDias;
  final DateTime ultimaRega;
  final String iluminacao;
  final int frequenciaFertilizacaoDias;
  final DateTime ultimaFertilizacao;

  PlantaModel({
    required this.id,
    required this.nome,
    required this.especie,
    this.fotoUrl,
    required this.intervaloRegaDias,
    required this.ultimaRega,
    required this.iluminacao,
    required this.frequenciaFertilizacaoDias,
    required this.ultimaFertilizacao,
  });

  // Calcula a data da próxima rega
  DateTime get proximaRega => ultimaRega.add(Duration(days: intervaloRegaDias));

  // Verifica se a planta precisa de rega hoje ou se está atrasada
  bool get precisaDeRega {
    final hoje = DateTime.now();
    final dataLimite = DateTime(proximaRega.year, proximaRega.month, proximaRega.day);
    final dataHoje = DateTime(hoje.year, hoje.month, hoje.day);
    return dataHoje.isAfter(dataLimite) || dataHoje.isAtSameMomentAs(dataLimite);
  }

  // Converte os dados salvos no Firebase (Map) para o formato do App
  factory PlantaModel.fromMap(String id, Map<String, dynamic> map) {
    return PlantaModel(
      id: id,
      nome: map['nome'] ?? '',
      especie: map['especie'] ?? '',
      fotoUrl: map['fotoUrl'],
      intervaloRegaDias: map['intervaloRegaDias'] ?? 3,
      ultimaRega: map['ultimaRega'] != null
          ? (map['ultimaRega'] as Timestamp).toDate()
          : DateTime.now(),
      iluminacao: map['iluminacao'] ?? 'Luz indireta',
      frequenciaFertilizacaoDias: map['frequenciaFertilizacaoDias'] ?? 30,
      ultimaFertilizacao: map['ultimaFertilizacao'] != null
          ? (map['ultimaFertilizacao'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  // Converte a Planta do App para salvar no banco do Firebase
  Map<String, dynamic> toMap() {
    return {
      'nome': nome,
      'especie': especie,
      'fotoUrl': fotoUrl,
      'intervaloRegaDias': intervaloRegaDias,
      'ultimaRega': Timestamp.fromDate(ultimaRega),
      'iluminacao': iluminacao,
      'frequenciaFertilizacaoDias': frequenciaFertilizacaoDias,
      'ultimaFertilizacao': Timestamp.fromDate(ultimaFertilizacao),
    };
  }
}