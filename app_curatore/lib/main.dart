import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/gestures.dart'; 

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://qzhywvvfabtycjpiukrd.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF6aHl3dnZmYWJ0eWNqcGl1a3JkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTEyMTY0MDksImV4cCI6MjEwNjc5MjQwOX0.cPVLoR83sTcenA_NU0GCFLlxD86vjtXZPwvGB_lJwR4',
  );
  runApp(const CuratoreApp());
}

class _MyCustomScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => { PointerDeviceKind.touch, PointerDeviceKind.mouse };
}

class CuratoreApp extends StatelessWidget {
  const CuratoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Curatore Personale',
      debugShowCheckedModeBanner: false,
      scrollBehavior: _MyCustomScrollBehavior(), 
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D0D12),
        useMaterial3: true,
      ),
      home: const GrafoSpaziale(),
    );
  }
}

class Nodo {
  final String id;
  final String tipo; 
  final String titolo;
  String contenuto; 
  Offset posizione;
  Offset velocita = Offset.zero; 
  final DateTime? dataCreazione;

  Nodo(this.id, this.tipo, this.titolo, this.contenuto, this.posizione, this.dataCreazione);
}

class GrafoSpaziale extends StatefulWidget {
  const GrafoSpaziale({super.key});
  @override
  State<GrafoSpaziale> createState() => _GrafoSpazialeState();
}

class _GrafoSpazialeState extends State<GrafoSpaziale> with SingleTickerProviderStateMixin {
  final double grandezzaSpazio = 3000.0; 
  
  List<Nodo> _nodi = [];
  List<dynamic> _connessioni = [];
  bool _staCaricandoIniziale = true;
  bool _posizioniSalvate = false; 
  
  late Ticker _motoreFisico; 
  late TransformationController _transformController; 
  final TextEditingController _controllerTesto = TextEditingController();
  bool _staCaricandoMessaggio = false;
  
  String? _nodoInFocus;
  int _movimentiMappa = 0;
  bool _generandoMistero = false;

  @override
  void initState() {
    super.initState();
    _transformController = TransformationController(
      Matrix4.identity()..translate(-grandezzaSpazio / 2 + 500, -grandezzaSpazio / 2 + 300)
    );
    _motoreFisico = createTicker((elapsed) { _calcolaFisica(); });
    _caricaDatiDalDatabase();
  }

  @override
  void dispose() {
    _motoreFisico.dispose(); 
    _transformController.dispose();
    super.dispose();
  }

  Future<void> _caricaDatiDalDatabase() async {
    final client = Supabase.instance.client;
    final frammenti = await client.from('frammenti').select();
    final connessioni = await client.from('connessioni').select();
    final random = Random();
    
    setState(() {
      _posizioniSalvate = false; 
      _nodi = frammenti.map((f) {
        double? dbX = f['pos_x'], dbY = f['pos_y'];
        double x = dbX ?? (grandezzaSpazio / 2) + (random.nextDouble() * 400 - 200);
        double y = dbY ?? (grandezzaSpazio / 2) + (random.nextDouble() * 400 - 200);
        
        DateTime? createdAt;
        if (f['created_at'] != null) {
          createdAt = DateTime.tryParse(f['created_at'].toString());
        }

        return Nodo(f['id'], f['tipo'] ?? 'riflessione', f['titolo'] ?? 'Senza titolo', f['contenuto_testuale'] ?? '', Offset(x, y), createdAt);
      }).toList();
      _connessioni = connessioni;
      _staCaricandoIniziale = false;
    });
    _motoreFisico.start();
  }

  Future<void> _salvaPosizioniNelDatabase() async {
    final client = Supabase.instance.client;
    final salvataggi = _nodi.where((n) => n.tipo != 'mistero').map((nodo) {
      return client.from('frammenti').update({ 'pos_x': nodo.posizione.dx, 'pos_y': nodo.posizione.dy }).eq('id', nodo.id);
    });
    try { await Future.wait(salvataggi); } catch (e) {}
  }
  
  Future<void> _eliminaNodo(String idNodo) async {
    final client = Supabase.instance.client;
    try {
      await client.from('connessioni').delete().or('nodo_origine_id.eq.$idNodo,nodo_destinazione_id.eq.$idNodo');
      await client.from('frammenti').delete().eq('id', idNodo);
      if (mounted) { Navigator.pop(context); _motoreFisico.stop(); await _caricaDatiDalDatabase(); }
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e'))); }
  }

  Future<void> _evocaNodoMisterioso() async {
    setState(() { _generandoMistero = true; });
    try {
      final url = Uri.parse('http://127.0.0.1:3000/api/mistero/genera');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final dati = jsonDecode(response.body)['dati'];
        
        final RenderBox renderBox = context.findRenderObject() as RenderBox;
        final Offset center = renderBox.size.center(Offset.zero);
        final Matrix4 matrix = _transformController.value.clone();
        matrix.invert();
        final Offset sceneCenter = MatrixUtils.transformPoint(matrix, center);
        
        final x = sceneCenter.dx + Random().nextDouble() * 300 - 150;
        final y = sceneCenter.dy + Random().nextDouble() * 300 - 150;
        
        final nodoMistero = Nodo('mistero_${DateTime.now().millisecondsSinceEpoch}', 'mistero', dati['titolo'], jsonEncode(dati), Offset(x, y), DateTime.now());
        
        setState(() { _nodi.add(nodoMistero); });
        _motoreFisico.start(); 

        Timer(const Duration(seconds: 45), () {
          if (mounted && _nodi.contains(nodoMistero)) { setState(() { _nodi.remove(nodoMistero); }); }
        });
      }
    } catch (e) { debugPrint("Mistero fallito: $e"); } finally { setState(() { _generandoMistero = false; }); }
  }

  void _calcolaFisica() {
    const double kRepulsione = 40000.0, kAttrazione = 0.015, kGravita = 0.0005, attrito = 0.85; 
    final Offset centroSpazio = Offset(grandezzaSpazio / 2, grandezzaSpazio / 2);
    Map<String, Offset> forze = { for (var n in _nodi) n.id : Offset.zero };
    double energiaTotale = 0.0; 

    for (int i = 0; i < _nodi.length; i++) {
      for (int j = i + 1; j < _nodi.length; j++) {
        final n1 = _nodi[i], n2 = _nodi[j];
        final delta = n1.posizione - n2.posizione;
        final distanza = delta.distance;
        if (distanza > 0 && distanza < 800) {
          final forzaRepulsiva = (delta / distanza) * (kRepulsione / (distanza * distanza));
          forze[n1.id] = forze[n1.id]! + forzaRepulsiva;
          forze[n2.id] = forze[n2.id]! - forzaRepulsiva;
        }
      }
    }

    for (final conn in _connessioni) {
      try {
        final n1 = _nodi.firstWhere((n) => n.id == conn['nodo_origine_id']);
        final n2 = _nodi.firstWhere((n) => n.id == conn['nodo_destinazione_id']);
        final delta = n2.posizione - n1.posizione;
        if (delta.distance > 0) {
          final forzaAttrattiva = delta * kAttrazione;
          forze[n1.id] = forze[n1.id]! + forzaAttrattiva;
          forze[n2.id] = forze[n2.id]! - forzaAttrattiva;
        }
      } catch(e) {}
    }

    for (var n in _nodi) {
      final deltaCentro = centroSpazio - n.posizione;
      forze[n.id] = forze[n.id]! + (deltaCentro * kGravita);
      n.velocita = (n.velocita + forze[n.id]!) * attrito;
      n.posizione += n.velocita;
      energiaTotale += n.velocita.distance; 
    }

    setState(() {});

    if (energiaTotale < (_nodi.length * 0.2) && !_posizioniSalvate && _nodi.isNotEmpty) {
      _posizioniSalvate = true; _motoreFisico.stop(); _salvaPosizioniNelDatabase(); 
    } else if (energiaTotale > (_nodi.length * 0.5)) {
      _posizioniSalvate = false;
    }
  }

  Future<void> _inviaPensiero() async {
    final testo = _controllerTesto.text.trim();
    if (testo.isEmpty) return;
    setState(() { _staCaricandoMessaggio = true; });
    try {
      final url = Uri.parse('http://127.0.0.1:3000/api/rifletti'); 
      final response = await http.post(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode({'testo': testo}));
      if (response.statusCode == 200) { _controllerTesto.clear(); _motoreFisico.stop(); await _caricaDatiDalDatabase(); } 
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e'))); } 
    finally { if (mounted) setState(() { _staCaricandoMessaggio = false; }); }
  }

  @override
  Widget build(BuildContext context) {
    if (_staCaricandoIniziale) return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.white38)));

    return Scaffold(
      body: Stack(
        children: [
          InteractiveViewer(
            constrained: false, panEnabled: true, scaleEnabled: true, boundaryMargin: const EdgeInsets.all(double.infinity),
            minScale: 0.1, maxScale: 2.0, transformationController: _transformController,
            onInteractionEnd: (details) {
              _movimentiMappa++;
              if (_movimentiMappa >= 8 && !_generandoMistero) { _movimentiMappa = 0; _evocaNodoMisterioso(); }
            },
            child: SizedBox(
              width: grandezzaSpazio, height: grandezzaSpazio,
              child: Stack(
                children: [
                  Positioned.fill(child: CustomPaint(painter: DisegnatoreArchi(_nodi, _connessioni, _nodoInFocus))),
                  ..._nodi.map((nodo) {
                    return Positioned(
                      left: nodo.posizione.dx - 60, top: nodo.posizione.dy - 15,
                      child: _costruisciPallinoNodo(nodo, context, _connessioni, _nodi),
                    );
                  }),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black, Colors.transparent])),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controllerTesto, style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: "Scrivi un pensiero...", hintStyle: const TextStyle(color: Colors.white54),
                        filled: true, fillColor: Colors.white.withOpacity(0.1),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      ),
                      onSubmitted: (_) => _inviaPensiero(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  CircleAvatar(
                    radius: 26, backgroundColor: Colors.indigoAccent,
                    child: _staCaricandoMessaggio 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : IconButton(icon: const Icon(Icons.send, color: Colors.white), onPressed: _inviaPensiero),
                  )
                ],
              ),
            ),
          ),
          
          const Positioned(top: 40, left: 20, child: Text('Wunderkammer', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white70))),
          
          Positioned(
            top: 30, right: 20, 
            child: IconButton(
              icon: const Icon(Icons.account_balance, color: Colors.amberAccent, size: 32),
              tooltip: 'Apri la Collezione',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => CabinetDelleCuriosita(nodi: _nodi)),
                );
              },
            ),
          )
        ],
      ),
    );
  }

  Widget _costruisciPallinoNodo(Nodo nodo, BuildContext context, List<dynamic> connessioni, List<Nodo> tuttiINodi) {
    final bool eScoperta = nodo.tipo == 'scoperta';
    final bool eMistero = nodo.tipo == 'mistero';
    final Color coloreBase = eMistero ? Colors.purpleAccent : (eScoperta ? Colors.amberAccent : Colors.indigoAccent);

    bool isInFocus = true;
    if (_nodoInFocus != null) {
      if (nodo.id == _nodoInFocus) { isInFocus = true; } 
      else {
        isInFocus = connessioni.any((c) => (c['nodo_origine_id'] == nodo.id && c['nodo_destinazione_id'] == _nodoInFocus) || (c['nodo_destinazione_id'] == nodo.id && c['nodo_origine_id'] == _nodoInFocus));
      }
    }

    return GestureDetector(
      onTap: () => _mostraDettagliNodo(context, nodo, connessioni, tuttiINodi),
      child: AnimatedOpacity(
        opacity: isInFocus ? 1.0 : 0.15, duration: const Duration(milliseconds: 300),
        child: SizedBox(
          width: 120, 
          child: Column(
            children: [
              Container(
                width: 30, height: 30, decoration: BoxDecoration(color: coloreBase, shape: BoxShape.circle, boxShadow: [BoxShadow(color: coloreBase.withOpacity(eMistero ? 0.9 : 0.6), blurRadius: eMistero ? 20 : 15, spreadRadius: 3)]),
                child: eMistero ? const Icon(Icons.help_outline, color: Colors.white, size: 18) : null,
              ),
              const SizedBox(height: 8),
              Text(
                nodo.titolo, textAlign: TextAlign.center,
                style: TextStyle(color: coloreBase, fontSize: 12, fontWeight: eScoperta || eMistero ? FontWeight.bold : FontWeight.w500),
                maxLines: 2, overflow: TextOverflow.ellipsis,
              )
            ],
          ),
        ),
      ),
    );
  }

  void _mostraDettagliNodo(BuildContext context, Nodo nodoCliccato, List<dynamic> connessioni, List<Nodo> tuttiINodi) {
    setState(() { _nodoInFocus = nodoCliccato.id; });

    if (nodoCliccato.tipo == 'mistero') {
      final datiMistero = jsonDecode(nodoCliccato.contenuto);
      final TextEditingController controllerMistero = TextEditingController();
      bool staRisolvendo = false;
      String testoMisteroAttuale = datiMistero['premessa'] ?? '';

      showModalBottomSheet(
        context: context, backgroundColor: const Color(0xFF1A1A24), isScrollControlled: true, 
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setStateModal) {
              return Padding(
                padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, top: 24, left: 24, right: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.auto_awesome, color: Colors.purpleAccent, size: 28), const SizedBox(width: 12),
                        Expanded(child: Text(datiMistero['titolo'] ?? 'Sincronicità', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.purpleAccent))),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(testoMisteroAttuale, style: const TextStyle(color: Colors.white, fontSize: 16, fontStyle: FontStyle.italic, height: 1.4)),
                    const SizedBox(height: 24),
                    TextField(
                      controller: controllerMistero, style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(hintText: "Qual è la tua deduzione?", hintStyle: const TextStyle(color: Colors.white38), filled: true, fillColor: Colors.black26, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none)), maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: staRisolvendo ? null : () async {
                          if (controllerMistero.text.trim().isEmpty) return;
                          setStateModal(() { staRisolvendo = true; });
                          try {
                            final url = Uri.parse('http://127.0.0.1:3000/api/mistero/risolvi');
                            final response = await http.post(url, headers: {'Content-Type': 'application/json'},
                              body: jsonEncode({
                                'titolo': datiMistero['titolo'],
                                'premessa': datiMistero['premessa'],
                                'verita_nascosta': datiMistero['verita_nascosta'],
                                'risposta_utente': controllerMistero.text.trim(),
                                'pos_x': nodoCliccato.posizione.dx, 'pos_y': nodoCliccato.posizione.dy
                              }),
                            );
                            if (response.statusCode == 200) {
                              final respJson = jsonDecode(response.body);
                              if (respJson['risolto'] == true) {
                                if (context.mounted) Navigator.pop(context); _motoreFisico.stop(); await _caricaDatiDalDatabase(); 
                              } else {
                                setStateModal(() { testoMisteroAttuale = respJson['nuovo_indizio']; controllerMistero.clear(); staRisolvendo = false; });
                              }
                            }
                          } catch (e) { setStateModal(() { staRisolvendo = false; }); }
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent, padding: const EdgeInsets.symmetric(vertical: 16)),
                        child: staRisolvendo ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Verifica Deduzione', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              );
            }
          );
        }
      ).whenComplete(() { setState(() { _nodoInFocus = null; }); });
      return;
    }

    final connessioniRilevanti = connessioni.where((c) => c['nodo_origine_id'] == nodoCliccato.id || c['nodo_destinazione_id'] == nodoCliccato.id).toList();
    int faseRH = 0; 
    Map<String, dynamic>? datiPolimata;
    String testoSfidaAttuale = ""; 
    final TextEditingController controllerSfida = TextEditingController();

    showModalBottomSheet(
      context: context, backgroundColor: const Color(0xFF1A1A24), isScrollControlled: true, 
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setStateModal) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(nodoCliccato.tipo == 'scoperta' ? Icons.lightbulb : Icons.person, color: nodoCliccato.tipo == 'scoperta' ? Colors.amberAccent : Colors.indigoAccent, size: 28),
                        const SizedBox(width: 12),
                        Expanded(child: Text(nodoCliccato.titolo, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: nodoCliccato.tipo == 'scoperta' ? Colors.amberAccent : Colors.indigoAccent))),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.white38),
                          onPressed: () async {
                            bool? conferma = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(backgroundColor: const Color(0xFF1A1A24), title: const Text('Dimenticare?', style: TextStyle(color: Colors.white)), actions: [
                                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annulla', style: TextStyle(color: Colors.white54))),
                                  TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Elimina', style: TextStyle(color: Colors.redAccent))),
                                ])
                            );
                            if (conferma == true) { _eliminaNodo(nodoCliccato.id); }
                          },
                        )
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(nodoCliccato.tipo == 'scoperta' ? 'Dalla Wunderkammer:' : 'Tu hai scritto:', style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.5))),
                    const SizedBox(height: 4),
                    Text(nodoCliccato.contenuto, style: const TextStyle(fontSize: 16, color: Colors.white, height: 1.4)),
                    const Divider(color: Colors.white24, height: 32),

                    // BOTTONE DEEP DIVE NEL DETTAGLIO NODO SCOPERTA
                    if (nodoCliccato.tipo == 'scoperta') ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.amberAccent)),
                            );
                            try {
                              final response = await http.post(
                                Uri.parse('http://127.0.0.1:3000/api/rabbithole/deepdive'),
                                headers: {'Content-Type': 'application/json'},
                                body: jsonEncode({
                                  'id_nodo': nodoCliccato.id,
                                  'titolo': nodoCliccato.titolo,
                                  'contenuto_base': nodoCliccato.contenuto
                                }),
                              );
                              Navigator.pop(context); 
                              if (response.statusCode == 200) {
                                final resJson = jsonDecode(response.body);
                                final saggio = resJson['saggio'];
                                final testoCompleto = "${nodoCliccato.contenuto}\n\n--- DEEP DIVE: ${saggio['titolo_saggio']} ---\n\n${saggio['testo_saggio']}";
                                nodoCliccato.contenuto = testoCompleto;
                                
                                if (context.mounted) {
                                  Navigator.pop(context); 
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => DeepDiveScreen(titolo: saggio['titolo_saggio'], testo: saggio['testo_saggio']),
                                    ),
                                  );
                                }
                              }
                            } catch (e) {
                              Navigator.pop(context);
                            }
                          },
                          icon: const Icon(Icons.menu_book, color: Colors.amberAccent),
                          label: const Text('Sprofonda (Deep Dive)', style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amberAccent.withOpacity(0.15),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.amberAccent.withOpacity(0.3)))
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    
                    if (connessioniRilevanti.isNotEmpty) ...[
                      Row(children: [const Icon(Icons.hub, color: Colors.white54, size: 18), const SizedBox(width: 8), Text('I fili del sapere:', style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.5)))]),
                      const SizedBox(height: 12),
                      ...connessioniRilevanti.map((conn) {
                        final idAltro = conn['nodo_origine_id'] == nodoCliccato.id ? conn['nodo_destinazione_id'] : conn['nodo_origine_id'];
                        String tit = "Nodo sconosciuto"; try { tit = tuttiINodi.firstWhere((n) => n.id == idAltro).titolo; } catch (e) {}
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('🔗 $tit', style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white70)),
                            const SizedBox(height: 8),
                            Text(conn['spiegazione_curatore'] ?? '', style: const TextStyle(color: Colors.white, fontStyle: FontStyle.italic, height: 1.3)),
                          ]),
                        );
                      }).toList(),
                    ],

                    if (nodoCliccato.tipo != 'scoperta') ...[
                      const SizedBox(height: 24),
                      if (faseRH == 0) 
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              setStateModal(() { faseRH = 1; });
                              try {
                                final response = await http.post(Uri.parse('http://127.0.0.1:3000/api/rabbithole/sfida'), headers: {'Content-Type': 'application/json'}, body: jsonEncode({ 'testo_origine': nodoCliccato.contenuto }));
                                if (response.statusCode == 200) { 
                                  datiPolimata = jsonDecode(response.body)['dati']; 
                                  testoSfidaAttuale = datiPolimata!['sfida_cognitiva'];
                                  setStateModal(() { faseRH = 2; }); 
                                }
                              } catch (e) { setStateModal(() { faseRH = 0; }); }
                            },
                            icon: const Icon(Icons.travel_explore, color: Colors.amberAccent), label: const Text('Esplora Rabbit Hole', style: TextStyle(color: Colors.amberAccent)),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.amberAccent.withOpacity(0.15), padding: const EdgeInsets.symmetric(vertical: 16))
                          ),
                        ),
                      if (faseRH == 1) const Center(child: CircularProgressIndicator(color: Colors.amberAccent)),
                      if (faseRH == 2 || faseRH == 3) 
                        Container(
                          padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.amberAccent.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.amberAccent.withOpacity(0.3))),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [const Icon(Icons.psychology, color: Colors.amberAccent), const SizedBox(width: 8), Text('Sfida del Polimata', style: TextStyle(color: Colors.amberAccent.withOpacity(0.8), fontWeight: FontWeight.bold))]),
                            const SizedBox(height: 12),
                            Text(testoSfidaAttuale, style: const TextStyle(color: Colors.white, fontSize: 16, fontStyle: FontStyle.italic)),
                            const SizedBox(height: 16),
                            TextField(controller: controllerSfida, style: const TextStyle(color: Colors.white), decoration: InputDecoration(filled: true, fillColor: Colors.black26, hintText: "La tua intuizione..."), maxLines: 2),
                            const SizedBox(height: 12),
                            SizedBox(width: double.infinity, child: ElevatedButton(
                              onPressed: faseRH == 3 ? null : () async {
                                if (controllerSfida.text.isEmpty) return; setStateModal(() { faseRH = 3; });
                                try {
                                  final response = await http.post(Uri.parse('http://127.0.0.1:3000/api/rabbithole/sblocca'), headers: {'Content-Type': 'application/json'}, body: jsonEncode({'id_nodo_origine': nodoCliccato.id, 'dati_polimata': datiPolimata, 'risposta_utente': controllerSfida.text.trim()}));
                                  if (response.statusCode == 200) { 
                                    final respJson = jsonDecode(response.body);
                                    if (respJson['risolto'] == true) {
                                      if (context.mounted) Navigator.pop(context); _motoreFisico.stop(); await _caricaDatiDalDatabase(); 
                                    } else {
                                      setStateModal(() { testoSfidaAttuale = respJson['nuovo_indizio']; controllerSfida.clear(); faseRH = 2; });
                                    }
                                  }
                                } catch (e) { setStateModal(() { faseRH = 2; }); }
                              },
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.amberAccent), child: faseRH == 3 ? const CircularProgressIndicator(color: Colors.black) : const Text('Verifica Deduzione', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold))
                            ))
                          ]),
                        ),
                    ]
                  ],
                ),
              ),
            );
          }
        );
      }
    ).whenComplete(() { setState(() { _nodoInFocus = null; }); });
  }
}

class DisegnatoreArchi extends CustomPainter {
  final List<Nodo> nodi; final List<dynamic> connessioni; final String? nodoInFocus; 
  DisegnatoreArchi(this.nodi, this.connessioni, this.nodoInFocus);

  @override
  void paint(Canvas canvas, Size size) {
    for (final conn in connessioni) {
      try {
        final id1 = conn['nodo_origine_id'], id2 = conn['nodo_destinazione_id'];
        final nodo1 = nodi.firstWhere((n) => n.id == id1), nodo2 = nodi.firstWhere((n) => n.id == id2);
        final bool cEFocus = nodoInFocus != null;
        final bool eArcoInFocus = cEFocus && (id1 == nodoInFocus || id2 == nodoInFocus);
        final pennello = Paint()..color = Colors.white.withOpacity(cEFocus ? (eArcoInFocus ? 0.6 : 0.05) : 0.2)..strokeWidth = eArcoInFocus ? 2.5 : 1.5..style = PaintingStyle.stroke;
        canvas.drawLine(nodo1.posizione, nodo2.posizione, pennello);
      } catch (e) {}
    }
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ----------------------------------------------------
// CABINET DELLE CURIOSITÀ (CON DEEP DIVE INTEGRATO)
// ----------------------------------------------------
class CabinetDelleCuriosita extends StatefulWidget {
  final List<Nodo> nodi;
  const CabinetDelleCuriosita({super.key, required this.nodi});

  @override
  State<CabinetDelleCuriosita> createState() => _CabinetDelleCuriositaState();
}

class _CabinetDelleCuriositaState extends State<CabinetDelleCuriosita> {
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  Future<void> _eseguiDeepDive(BuildContext context, Nodo scoperta) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.amberAccent),
            SizedBox(height: 16),
            Text("Il saggista sta scrivendo l'immersione verticale...", style: TextStyle(color: Colors.white70, fontSize: 14)),
          ],
        ),
      ),
    );

    try {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:3000/api/rabbithole/deepdive'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id_nodo': scoperta.id,
          'titolo': scoperta.titolo,
          'contenuto_base': scoperta.contenuto
        }),
      );

      Navigator.pop(context); 

      if (response.statusCode == 200) {
        final resJson = jsonDecode(response.body);
        final saggio = resJson['saggio'];
        
        final testoCompleto = "${scoperta.contenuto}\n\n--- DEEP DIVE: ${saggio['titolo_saggio']} ---\n\n${saggio['testo_saggio']}";
        setState(() {
          scoperta.contenuto = testoCompleto;
        });

        if (context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DeepDiveScreen(titolo: saggio['titolo_saggio'], testo: saggio['testo_saggio']),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore Deep Dive: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    int scoperteTotali = widget.nodi.where((n) => n.tipo == 'scoperta').length;
    
    final now = DateTime.now();
    int pensieriOggi = widget.nodi.where((n) {
      if (n.tipo != 'riflessione' || n.dataCreazione == null) return false;
      return n.dataCreazione!.year == now.year && 
             n.dataCreazione!.month == now.month && 
             n.dataCreazione!.day == now.day;
    }).length;

    List<Nodo> scoperteFiltrate = widget.nodi.where((n) {
      if (n.tipo != 'scoperta') return false;
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return n.titolo.toLowerCase().contains(q) || n.contenuto.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D12),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Cabinet of Curiosities', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amberAccent)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.indigoAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.indigoAccent.withOpacity(0.3))),
                    child: Column(
                      children: [
                        const Icon(Icons.track_changes, color: Colors.indigoAccent), const SizedBox(height: 8),
                        const Text("Pensieri Oggi", style: TextStyle(color: Colors.white54, fontSize: 12)),
                        Text("$pensieriOggi / 3", style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.amberAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.amberAccent.withOpacity(0.3))),
                    child: Column(
                      children: [
                        const Icon(Icons.auto_awesome_mosaic, color: Colors.amberAccent), const SizedBox(height: 8),
                        const Text("Scoperte Totali", style: TextStyle(color: Colors.white54, fontSize: 12)),
                        Text("$scoperteTotali", style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Cerca tra le tue scoperte...",
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                filled: true, fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 24),

            Expanded(
              child: scoperteFiltrate.isEmpty
                ? const Center(child: Text("Nessuna scoperta trovata.", style: TextStyle(color: Colors.white54)))
                : ListView.builder(
                    itemCount: scoperteFiltrate.length,
                    itemBuilder: (context, index) {
                      final scoperta = scoperteFiltrate[index];
                      final bool haDeepDive = scoperta.contenuto.contains("--- DEEP DIVE");

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.amberAccent.withOpacity(0.2))
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.lightbulb, color: Colors.amberAccent, size: 20),
                                const SizedBox(width: 8),
                                Expanded(child: Text(scoperta.titolo, style: const TextStyle(color: Colors.amberAccent, fontSize: 18, fontWeight: FontWeight.bold))),
                                
                                TextButton.icon(
                                  onPressed: () {
                                    if (haDeepDive) {
                                      final parts = scoperta.contenuto.split("--- DEEP DIVE:");
                                      final saggioTesto = parts.length > 1 ? parts[1] : scoperta.contenuto;
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => DeepDiveScreen(titolo: scoperta.titolo, testo: saggioTesto),
                                        ),
                                      );
                                    } else {
                                      _eseguiDeepDive(context, scoperta);
                                    }
                                  },
                                  icon: Icon(haDeepDive ? Icons.menu_book : Icons.auto_stories, color: Colors.amberAccent, size: 16),
                                  label: Text(haDeepDive ? "Leggi Saggio" : "Sprofonda", style: const TextStyle(color: Colors.amberAccent, fontSize: 12)),
                                  style: TextButton.styleFrom(backgroundColor: Colors.amberAccent.withOpacity(0.1)),
                                )
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              scoperta.contenuto,
                              style: const TextStyle(color: Colors.white70, height: 1.4),
                              maxLines: 3, 
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
            )
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------
// SCHERMATA IMMERSIVA DEEP DIVE READER
// ----------------------------------------------------
class DeepDiveScreen extends StatelessWidget {
  final String titolo;
  final String testo;

  const DeepDiveScreen({super.key, required this.titolo, required this.testo});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D12),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(titolo, style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.menu_book, color: Colors.amberAccent, size: 20),
                const SizedBox(width: 8),
                const Text("IMMERSIONE VERTICALE • DEEP DIVE", style: TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: 1.5)),
              ],
            ),
            const Divider(color: Colors.white24, height: 32),
            Text(
              testo,
              style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.6),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}