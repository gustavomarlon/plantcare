
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/planta_model.dart';
import 'form_planta_screen.dart';
import 'detalhes_planta_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Stream<QuerySnapshot<Map<String, dynamic>>> _buscarPlantas() {
    final usuario = FirebaseAuth.instance.currentUser;

    if (usuario == null) {
      return const Stream.empty();
    }

    return FirebaseFirestore.instance
        .collection('usuarios')
        .doc(usuario.uid)
        .collection('plantas')
        .snapshots();
  }

  Future<void> _sair() async {
    await FirebaseAuth.instance.signOut();

    if (!mounted) return;

    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<Widget> _fotoDaPlanta(PlantaModel planta) async {
    final usuario = FirebaseAuth.instance.currentUser;

    if (usuario == null) {
      return _iconePlanta();
    }

    final chave =
        'plantcare_foto_${usuario.uid}_${planta.id}';

    try {
      final preferencias =
          await SharedPreferences.getInstance();

      final imagemBase64 =
          preferencias.getString(chave);

      if (imagemBase64 == null || imagemBase64.isEmpty) {
        return _iconePlanta();
      }

      final bytes = base64Decode(imagemBase64);

      return ClipOval(
        child: Image.memory(
          bytes,
          width: 54,
          height: 54,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _iconePlanta();
          },
        ),
      );
    } catch (erro) {
      debugPrint('Erro ao carregar foto da planta: $erro');
      return _iconePlanta();
    }
  }

  Widget _iconePlanta() {
    return const Icon(
      Icons.local_florist,
      color: Color(0xFF2E7D32),
      size: 29,
    );
  }

  Widget _cartaoResumo({
    required String titulo,
    required int quantidade,
    required IconData icone,
    required Color cor,
  }) {
    return Expanded(
      child: Card(
        elevation: 1,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: 14,
            horizontal: 6,
          ),
          child: Column(
            children: [
              Icon(icone, color: cor, size: 27),
              const SizedBox(height: 8),
              Text(
                '$quantidade',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                titulo,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PlantCare 🌿'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
            onPressed: _sair,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Olá, Colecionador! 👋',
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Como está seu jardim hoje?',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: StreamBuilder<
                  QuerySnapshot<Map<String, dynamic>>>(
                stream: _buscarPlantas(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Erro ao carregar plantas:\n${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  if (snapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  final documentos =
                      snapshot.data?.docs ?? [];

                  final plantas = documentos.map((documento) {
                    return PlantaModel.fromMap(
                      documento.id,
                      documento.data(),
                    );
                  }).toList();

                  final total = plantas.length;
                  final precisamDeRega =
                      plantas.where((p) => p.precisaDeRega).length;
                  final emDia = total - precisamDeRega;

                  return Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _cartaoResumo(
                            titulo: 'Total',
                            quantidade: total,
                            icone: Icons.local_florist,
                            cor: const Color(0xFF2E7D32),
                          ),
                          _cartaoResumo(
                            titulo: 'Regar hoje',
                            quantidade: precisamDeRega,
                            icone: Icons.water_drop,
                            cor: Colors.red,
                          ),
                          _cartaoResumo(
                            titulo: 'Em dia',
                            quantidade: emDia,
                            icone: Icons.check_circle,
                            cor: Colors.green,
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Minhas plantas',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (plantas.isEmpty)
                        const Expanded(
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.local_florist,
                                  size: 64,
                                  color: Color(0xFF81C784),
                                ),
                                SizedBox(height: 12),
                                Text(
                                  'Seu jardim está esperando!',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  'Toque em "Nova Planta" para começar.',
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        Expanded(
                          child: ListView.builder(
                            itemCount: plantas.length,
                            itemBuilder: (context, index) {
                              final planta = plantas[index];
                              final precisaDeRega =
                                  planta.precisaDeRega;

                              return Card(
                                margin: const EdgeInsets.only(
                                  bottom: 10,
                                ),
                                child: ListTile(
                                  contentPadding:
                                      const EdgeInsets.all(12),
                                  leading: CircleAvatar(
                                    radius: 27,
                                    backgroundColor:
                                        const Color(0xFF81C784)
                                            .withValues(alpha: 0.3),
                                    child: FutureBuilder<Widget>(
                                      future: _fotoDaPlanta(planta),
                                      builder: (context, snapshot) {
                                        if (snapshot.connectionState ==
                                            ConnectionState.waiting) {
                                          return const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child:
                                                CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          );
                                        }

                                        return snapshot.data ??
                                            _iconePlanta();
                                      },
                                    ),
                                  ),
                                  title: Text(
                                    planta.nome,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Padding(
                                    padding:
                                        const EdgeInsets.only(top: 6),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(planta.especie),
                                        const SizedBox(height: 7),
                                        Container(
                                          padding:
                                              const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: precisaDeRega
                                                ? Colors.red.withValues(
                                                    alpha: 0.12,
                                                  )
                                                : Colors.green.withValues(
                                                    alpha: 0.12,
                                                  ),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            mainAxisSize:
                                                MainAxisSize.min,
                                            children: [
                                              Icon(
                                                precisaDeRega
                                                    ? Icons
                                                        .warning_amber_rounded
                                                    : Icons
                                                        .check_circle_outline,
                                                size: 15,
                                                color: precisaDeRega
                                                    ? Colors.red
                                                    : Colors.green,
                                              ),
                                              const SizedBox(width: 5),
                                              Text(
                                                precisaDeRega
                                                    ? 'Precisa de água!'
                                                    : 'Em dia',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight:
                                                      FontWeight.bold,
                                                  color: precisaDeRega
                                                      ? Colors.red
                                                      : Colors.green,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  trailing: const Icon(
                                    Icons.arrow_forward_ios,
                                    size: 16,
                                  ),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            DetalhesPlantaScreen(
                                          planta: planta,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const FormPlantaScreen(),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Nova Planta'),
      ),
    );
  }
}
