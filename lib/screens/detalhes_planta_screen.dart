
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/planta_model.dart';
import 'form_planta_screen.dart';

class DetalhesPlantaScreen extends StatefulWidget {
  final PlantaModel planta;

  const DetalhesPlantaScreen({
    super.key,
    required this.planta,
  });

  @override
  State<DetalhesPlantaScreen> createState() =>
      _DetalhesPlantaScreenState();
}

class _DetalhesPlantaScreenState
    extends State<DetalhesPlantaScreen> {
  late PlantaModel _planta;

  Uint8List? _imagemBytes;
  bool _carregandoFoto = false;
  bool _registrandoRega = false;
  bool _registrandoFertilizacao = false;
  bool _excluindoPlanta = false;

  @override
  void initState() {
    super.initState();
    _planta = widget.planta;
    _carregarFotoLocal();
  }

  Future<void> _carregarFotoLocal() async {
    final usuario = FirebaseAuth.instance.currentUser;

    if (usuario == null) return;

    setState(() => _carregandoFoto = true);

    try {
      final preferencias =
          await SharedPreferences.getInstance();

      final chave =
          'plantcare_foto_${usuario.uid}_${_planta.id}';

      final fotoSalva = preferencias.getString(chave);

      if (fotoSalva != null && fotoSalva.isNotEmpty) {
        final bytes = base64Decode(fotoSalva);

        if (!mounted) return;

        setState(() => _imagemBytes = bytes);
        debugPrint('Foto carregada nos detalhes: ${bytes.length} bytes');
      }
    } catch (e) {
      debugPrint('Erro ao carregar foto nos detalhes: $e');
    } finally {
      if (mounted) {
        setState(() => _carregandoFoto = false);
      }
    }
  }

  DocumentReference<Map<String, dynamic>> _plantaRef(
    String uid,
  ) {
    return FirebaseFirestore.instance
        .collection('usuarios')
        .doc(uid)
        .collection('plantas')
        .doc(_planta.id);
  }

  CollectionReference<Map<String, dynamic>> _historicoRef(
    String uid,
    String tipo,
  ) {
    return _plantaRef(uid).collection(
      tipo == 'rega'
          ? 'historico_regas'
          : 'historico_fertilizacoes',
    );
  }

  Future<void> _registrarCuidado({
    required bool rega,
  }) async {
    if (rega && _registrandoRega) return;
    if (!rega && _registrandoFertilizacao) return;

    final usuario = FirebaseAuth.instance.currentUser;

    if (usuario == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Faça login para registrar o cuidado.'),
        ),
      );
      return;
    }

    setState(() {
      if (rega) {
        _registrandoRega = true;
      } else {
        _registrandoFertilizacao = true;
      }
    });

    try {
      final agora = DateTime.now();
      final campoData =
          rega ? 'ultimaRega' : 'ultimaFertilizacao';
      final nomeCuidado = rega ? 'Rega' : 'Fertilização';

      final lote = FirebaseFirestore.instance.batch();

      lote.update(_plantaRef(usuario.uid), {
        campoData: Timestamp.fromDate(agora),
      });

      final novoRegistro =
          _historicoRef(
            usuario.uid,
            rega ? 'rega' : 'fertilizacao',
          ).doc();

      lote.set(novoRegistro, {
        'data': Timestamp.fromDate(agora),
        'tipo': rega ? 'rega' : 'fertilizacao',
        'descricao': rega
            ? 'Rega realizada'
            : 'Fertilização realizada',
      });

      await lote.commit();

      if (!mounted) return;

      setState(() {
        _planta = PlantaModel(
          id: _planta.id,
          nome: _planta.nome,
          especie: _planta.especie,
          fotoUrl: _planta.fotoUrl,
          intervaloRegaDias: _planta.intervaloRegaDias,
          ultimaRega: rega ? agora : _planta.ultimaRega,
          iluminacao: _planta.iluminacao,
          frequenciaFertilizacaoDias:
              _planta.frequenciaFertilizacaoDias,
          ultimaFertilizacao:
              rega ? _planta.ultimaFertilizacao : agora,
        );
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$nomeCuidado registrada com sucesso! 🌿',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao salvar o cuidado: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          if (rega) {
            _registrandoRega = false;
          } else {
            _registrandoFertilizacao = false;
          }
        });
      }
    }
  }

  Future<void> _excluirPlanta() async {
    if (_excluindoPlanta) return;

    final usuario = FirebaseAuth.instance.currentUser;
    if (usuario == null) return;

    setState(() => _excluindoPlanta = true);

    try {
      for (final tipo in ['rega', 'fertilizacao']) {
        final historico =
            await _historicoRef(usuario.uid, tipo).get();

        for (final registro in historico.docs) {
          await registro.reference.delete();
        }
      }

      // Exclui a planta do Firestore.
      await _plantaRef(usuario.uid).delete();

      // Remove também a foto local dessa planta.
      final preferencias =
          await SharedPreferences.getInstance();
      final chave =
          'plantcare_foto_${usuario.uid}_${_planta.id}';
      await preferencias.remove(chave);

      if (!mounted) return;

      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;

      setState(() => _excluindoPlanta = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao excluir a planta: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _confirmarExclusao() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir planta'),
        content: Text(
          'Deseja excluir "${_planta.nome}"? '
          'Os históricos desta planta também serão excluídos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCELAR'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _excluirPlanta();
            },
            child: const Text(
              'EXCLUIR',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  String _formatarData(DateTime data) {
    final dia = data.day.toString().padLeft(2, '0');
    final mes = data.month.toString().padLeft(2, '0');
    final ano = data.year.toString();
    final hora = data.hour.toString().padLeft(2, '0');
    final minuto = data.minute.toString().padLeft(2, '0');

    return '$dia/$mes/$ano às $hora:$minuto';
  }

  DateTime get _proximaFertilizacao {
    return _planta.ultimaFertilizacao.add(
      Duration(
        days: _planta.frequenciaFertilizacaoDias,
      ),
    );
  }

  bool get _precisaDeFertilizacao {
    final agora = DateTime.now();
    final proxima = _proximaFertilizacao;

    return !DateTime(
      agora.year,
      agora.month,
      agora.day,
    ).isBefore(
      DateTime(
        proxima.year,
        proxima.month,
        proxima.day,
      ),
    );
  }

  Widget _construirHistorico({
    required String tipo,
  }) {
    final usuario = FirebaseAuth.instance.currentUser;

    if (usuario == null) {
      return const Text(
        'Entre na sua conta para ver o histórico.',
      );
    }

    final ehRega = tipo == 'rega';

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _historicoRef(usuario.uid, tipo)
          .orderBy('data', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Não foi possível carregar o histórico.',
            ),
          );
        }

        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final registros = snapshot.data?.docs ?? [];

        if (registros.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              ehRega
                  ? 'Nenhuma rega registrada ainda.'
                  : 'Nenhuma fertilização registrada ainda.',
            ),
          );
        }

        return Column(
          children: registros.map((registro) {
            final dados = registro.data();
            final valorData = dados['data'];

            if (valorData is! Timestamp) {
              return const SizedBox.shrink();
            }

            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: ehRega
                    ? const Color(0xFFE3F2FD)
                    : const Color(0xFFE8F5E9),
                child: Icon(
                  ehRega ? Icons.water_drop : Icons.eco,
                  color: ehRega ? Colors.blue : Colors.green,
                ),
              ),
              title: Text(
                ehRega
                    ? 'Rega realizada'
                    : 'Fertilização realizada',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                _formatarData(valorData.toDate()),
              ),
              trailing: const Icon(
                Icons.check_circle_outline,
                color: Colors.green,
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _cartaoStatus({
    required bool alerta,
    required IconData icone,
    required String titulo,
    required String descricao,
  }) {
    final cor = alerta ? Colors.red : Colors.green;

    return Card(
      color: alerta
          ? Colors.red.shade50
          : Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icone, color: cor, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: alerta
                          ? Colors.red.shade800
                          : Colors.green.shade800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    descricao,
                    style: TextStyle(
                      color: alerta
                          ? Colors.red.shade700
                          : Colors.green.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final precisaFertilizar = _precisaDeFertilizacao;

    return Scaffold(
      appBar: AppBar(
        title: Text(_planta.nome),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Editar planta',
            onPressed: () async {
              final resultado = await Navigator.push<PlantaModel>(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      FormPlantaScreen(planta: _planta),
                ),
              );

              if (resultado != null && mounted) {
                setState(() {
                  _planta = resultado;
                });

                await _carregarFotoLocal();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Excluir planta',
            onPressed:
                _excluindoPlanta ? null : _confirmarExclusao,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: CircleAvatar(
                radius: 60,
                backgroundColor:
                    const Color(0xFF81C784).withValues(alpha: 0.3),
                backgroundImage: _imagemBytes != null
                    ? MemoryImage(_imagemBytes!)
                    : null,
                child: _carregandoFoto
                    ? const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : _imagemBytes == null
                        ? const Icon(
                            Icons.local_florist,
                            size: 70,
                            color: Color(0xFF2E7D32),
                          )
                        : null,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _planta.nome,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              _planta.especie,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontStyle: FontStyle.italic,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),

            _cartaoStatus(
              alerta: _planta.precisaDeRega,
              icone: _planta.precisaDeRega
                  ? Icons.warning_amber_rounded
                  : Icons.check_circle_outline,
              titulo: _planta.precisaDeRega
                  ? 'Precisa de rega!'
                  : 'Rega em dia',
              descricao: _planta.precisaDeRega
                  ? 'Já chegou a data prevista para regar.'
                  : 'A próxima rega ainda não venceu.',
            ),

            const SizedBox(height: 12),

            _cartaoStatus(
              alerta: precisaFertilizar,
              icone: precisaFertilizar
                  ? Icons.warning_amber_rounded
                  : Icons.eco,
              titulo: precisaFertilizar
                  ? 'Precisa de fertilização!'
                  : 'Fertilização em dia',
              descricao: precisaFertilizar
                  ? 'Já chegou a data prevista para fertilizar.'
                  : 'Próxima fertilização: '
                      '${_formatarData(_proximaFertilizacao)}',
            ),

            const SizedBox(height: 24),
            const Text(
              'Informações de cultivo',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            ListTile(
              leading: const Icon(
                Icons.water_drop,
                color: Colors.blue,
              ),
              title: const Text('Frequência de rega'),
              subtitle: Text(
                'A cada ${_planta.intervaloRegaDias} dias',
              ),
            ),
            const Divider(),

            ListTile(
              leading: const Icon(
                Icons.wb_sunny,
                color: Colors.amber,
              ),
              title: const Text('Iluminação recomendada'),
              subtitle: Text(_planta.iluminacao),
            ),
            const Divider(),

            ListTile(
              leading: const Icon(
                Icons.eco,
                color: Colors.green,
              ),
              title: const Text('Frequência de fertilização'),
              subtitle: Text(
                'A cada ${_planta.frequenciaFertilizacaoDias} dias',
              ),
            ),

            const SizedBox(height: 24),

            ElevatedButton.icon(
              onPressed: _registrandoRega
                  ? null
                  : () => _registrarCuidado(rega: true),
              icon: _registrandoRega
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.water_drop_outlined),
              label: Text(
                _registrandoRega
                    ? 'SALVANDO REGA...'
                    : 'REGISTRAR REGA HOJE',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 12),

            OutlinedButton.icon(
              onPressed: _registrandoFertilizacao
                  ? null
                  : () => _registrarCuidado(rega: false),
              icon: _registrandoFertilizacao
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.green,
                      ),
                    )
                  : const Icon(Icons.eco_outlined),
              label: Text(
                _registrandoFertilizacao
                    ? 'SALVANDO FERTILIZAÇÃO...'
                    : 'REGISTRAR FERTILIZAÇÃO',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF2E7D32),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 28),
            const Text(
              'Histórico de regas',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: _construirHistorico(tipo: 'rega'),
              ),
            ),

            const SizedBox(height: 24),
            const Text(
              'Histórico de fertilizações',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: _construirHistorico(
                  tipo: 'fertilizacao',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
