
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/planta_model.dart';

class FormPlantaScreen extends StatefulWidget {
  final PlantaModel? planta;

  const FormPlantaScreen({super.key, this.planta});

  @override
  State<FormPlantaScreen> createState() => _FormPlantaScreenState();
}

class _FormPlantaScreenState extends State<FormPlantaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _especieController = TextEditingController();
  final _intervaloRegaController = TextEditingController(text: '3');
  final _frequenciaFertilizaController =
      TextEditingController(text: '15');

  final ImagePicker _imagePicker = ImagePicker();

  Uint8List? _imagemBytes;
  bool _salvando = false;
  bool _carregandoFoto = false;
  String? _fotoUrl;

  String _iluminacaoSelecionada = 'Luz indireta';

  final List<String> _opcoesIluminacao = [
    'Sombra',
    'Luz indireta',
    'Sol pleno',
    'Meia-sombra',
  ];

  @override
  void initState() {
    super.initState();

    final planta = widget.planta;

    if (planta != null) {
      _nomeController.text = planta.nome;
      _especieController.text = planta.especie;
      _intervaloRegaController.text =
          planta.intervaloRegaDias.toString();
      _frequenciaFertilizaController.text =
          planta.frequenciaFertilizacaoDias.toString();

      _iluminacaoSelecionada =
          _opcoesIluminacao.contains(planta.iluminacao)
              ? planta.iluminacao
              : 'Luz indireta';

      _fotoUrl = planta.fotoUrl;
      _carregarFotoLocal();
    }
  }

  String _chaveFoto(String uid, String plantaId) {
    return 'plantcare_foto_${uid}_$plantaId';
  }

  Future<void> _carregarFotoLocal() async {
    final usuario = FirebaseAuth.instance.currentUser;
    final planta = widget.planta;

    if (usuario == null || planta == null) return;

    setState(() => _carregandoFoto = true);

    try {
      final preferencias = await SharedPreferences.getInstance();
      final chave = _chaveFoto(usuario.uid, planta.id);
      final fotoSalva = preferencias.getString(chave);

      if (fotoSalva != null && fotoSalva.isNotEmpty) {
        final bytes = base64Decode(fotoSalva);

        if (!mounted) return;

        setState(() => _imagemBytes = bytes);
        debugPrint('Foto carregada: ${bytes.length} bytes');
      } else {
        debugPrint('Nenhuma foto local encontrada para $chave');
      }
    } catch (e, stackTrace) {
      debugPrint('Erro ao carregar foto: $e');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      if (mounted) {
        setState(() => _carregandoFoto = false);
      }
    }
  }

  Future<void> _selecionarFoto() async {
    try {
      final imagem = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 60,
        maxWidth: 800,
        maxHeight: 800,
      );

      if (imagem == null) return;

      final bytes = await imagem.readAsBytes();

      if (!mounted) return;

      setState(() => _imagemBytes = bytes);

      debugPrint('Foto selecionada: ${bytes.length} bytes');
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao escolher foto: $e')),
      );
    }
  }

  Future<void> _salvarPlanta() async {
    if (_salvando || !_formKey.currentState!.validate()) return;

    final usuario = FirebaseAuth.instance.currentUser;

    if (usuario == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Faça login para salvar a planta.'),
        ),
      );
      return;
    }

    final intervalo = int.tryParse(_intervaloRegaController.text);
    final fertilizacao =
        int.tryParse(_frequenciaFertilizaController.text);

    if (intervalo == null ||
        intervalo < 1 ||
        fertilizacao == null ||
        fertilizacao < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe intervalos de pelo menos 1 dia.'),
        ),
      );
      return;
    }

    setState(() => _salvando = true);

    try {
      final plantasRef = FirebaseFirestore.instance
          .collection('usuarios')
          .doc(usuario.uid)
          .collection('plantas');

      final existente = widget.planta;

      final plantaRef = existente == null
          ? plantasRef.doc()
          : plantasRef.doc(existente.id);

      String? fotoSalva = _fotoUrl;

      // Salva a imagem localmente antes de gravar a planta.
      if (_imagemBytes != null) {
        final preferencias = await SharedPreferences.getInstance();
        final chave = _chaveFoto(usuario.uid, plantaRef.id);
        final dados = base64Encode(_imagemBytes!);

        final sucesso = await preferencias.setString(chave, dados);

        debugPrint('Foto salva no navegador: $sucesso');
        debugPrint('Tamanho da foto: ${_imagemBytes!.length} bytes');

        final confirmacao = preferencias.getString(chave);

        if (!sucesso || confirmacao != dados) {
          throw Exception(
            'Não foi possível confirmar o salvamento da foto. '
            'Tente uma imagem menor.',
          );
        }

        fotoSalva = 'local-foto:$chave';
      }

      final planta = PlantaModel(
        id: plantaRef.id,
        nome: _nomeController.text.trim(),
        especie: _especieController.text.trim(),
        fotoUrl: fotoSalva,
        intervaloRegaDias: intervalo,
        ultimaRega: existente?.ultimaRega ?? DateTime.now(),
        iluminacao: _iluminacaoSelecionada,
        frequenciaFertilizacaoDias: fertilizacao,
        ultimaFertilizacao:
            existente?.ultimaFertilizacao ?? DateTime.now(),
      );

      await plantaRef.set(planta.toMap());

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            existente == null
                ? 'Planta cadastrada com sucesso!'
                : 'Planta atualizada com sucesso!',
          ),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, planta);
    } catch (e, stackTrace) {
      debugPrint('Erro ao salvar planta: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao salvar a planta: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _salvando = false);
      }
    }
  }

  Widget _construirFoto() {
    ImageProvider? imagem;

    if (_imagemBytes != null) {
      imagem = MemoryImage(_imagemBytes!);
    } else if (_fotoUrl != null &&
        _fotoUrl!.isNotEmpty &&
        !_fotoUrl!.startsWith('local-foto:')) {
      imagem = NetworkImage(_fotoUrl!);
    }

    return Center(
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 58,
                backgroundColor: Colors.green.withValues(alpha: 0.15),
                backgroundImage: imagem,
                child: _carregandoFoto
                    ? const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : imagem == null
                        ? const Icon(
                            Icons.local_florist,
                            size: 58,
                            color: Colors.green,
                          )
                        : null,
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: CircleAvatar(
                  backgroundColor: Colors.green,
                  child: IconButton(
                    tooltip: 'Escolher foto',
                    onPressed: _salvando ? null : _selecionarFoto,
                    icon: const Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _salvando ? null : _selecionarFoto,
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Escolher foto da galeria'),
          ),
          if (_imagemBytes != null)
            const Text(
              'Foto selecionada',
              style: TextStyle(fontSize: 12),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _especieController.dispose();
    _intervaloRegaController.dispose();
    _frequenciaFertilizaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdicao = widget.planta != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdicao ? 'Editar Planta' : 'Nova Planta'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _construirFoto(),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nomeController,
                decoration: const InputDecoration(
                  labelText: 'Nome da planta',
                  prefixIcon: Icon(Icons.eco_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (valor) =>
                    valor == null || valor.trim().isEmpty
                        ? 'Informe o nome da planta.'
                        : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _especieController,
                decoration: const InputDecoration(
                  labelText: 'Espécie',
                  prefixIcon: Icon(Icons.local_florist_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (valor) =>
                    valor == null || valor.trim().isEmpty
                        ? 'Informe a espécie.'
                        : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _intervaloRegaController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Intervalo de rega (dias)',
                  prefixIcon: Icon(Icons.water_drop_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (valor) {
                  final numero = int.tryParse(valor ?? '');
                  return numero == null || numero < 1
                      ? 'Informe um número de dias válido.'
                      : null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _iluminacaoSelecionada,
                decoration: const InputDecoration(
                  labelText: 'Iluminação',
                  prefixIcon: Icon(Icons.wb_sunny_outlined),
                  border: OutlineInputBorder(),
                ),
                items: _opcoesIluminacao.map((opcao) {
                  return DropdownMenuItem(
                    value: opcao,
                    child: Text(opcao),
                  );
                }).toList(),
                onChanged: _salvando
                    ? null
                    : (valor) {
                        if (valor != null) {
                          setState(() {
                            _iluminacaoSelecionada = valor;
                          });
                        }
                      },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _frequenciaFertilizaController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Frequência de fertilização (dias)',
                  prefixIcon: Icon(Icons.compost_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (valor) {
                  final numero = int.tryParse(valor ?? '');
                  return numero == null || numero < 1
                      ? 'Informe um número de dias válido.'
                      : null;
                },
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _salvando ? null : _salvarPlanta,
                icon: _salvando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(
                  _salvando ? 'Salvando...' : 'Salvar planta',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
