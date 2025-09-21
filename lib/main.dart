import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const AplikasiKeuangan());
}

class AplikasiKeuangan extends StatelessWidget {
  const AplikasiKeuangan({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Catatan Keuangan',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.grey[100],
      ),
      home: const Beranda(),
    );
  }
}

class Beranda extends StatefulWidget {
  const Beranda({super.key});

  @override
  State<Beranda> createState() => _BerandaState();
}

class _BerandaState extends State<Beranda> {
  final TextEditingController _deskripsiCtrl = TextEditingController();
  final TextEditingController _jumlahCtrl = TextEditingController();
  String _tipe = "Pemasukan";
  final _rupiah = NumberFormat.currency(locale: "id_ID", symbol: "Rp", decimalDigits: 0);

  Future<void> _tambahCatatan() async {
    final deskripsi = _deskripsiCtrl.text.trim();
    final jumlahText = _jumlahCtrl.text.trim();
    if (deskripsi.isEmpty || jumlahText.isEmpty) return;
    final jumlah = double.tryParse(jumlahText);
    if (jumlah == null) return;
    await FirebaseFirestore.instance.collection("catatan").add({
      "deskripsi": deskripsi,
      "jumlah": jumlah,
      "tipe": _tipe,
      "waktu": FieldValue.serverTimestamp(),
    });
    _deskripsiCtrl.clear();
    _jumlahCtrl.clear();
  }

  Future<void> _hapusCatatan(String id) async {
    await FirebaseFirestore.instance.collection("catatan").doc(id).delete();
  }

  Future<void> _editCatatan(String id, String lamaDeskripsi, double lamaJumlah, String lamaTipe) async {
    _deskripsiCtrl.text = lamaDeskripsi;
    _jumlahCtrl.text = lamaJumlah.toString();
    _tipe = lamaTipe;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Edit Catatan"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _deskripsiCtrl,
                decoration: const InputDecoration(labelText: "Deskripsi"),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _jumlahCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Jumlah (Rp)"),
              ),
              const SizedBox(height: 10),
              DropdownButton<String>(
                value: _tipe,
                items: const [
                  DropdownMenuItem(value: "Pemasukan", child: Text("Pemasukan")),
                  DropdownMenuItem(value: "Pengeluaran", child: Text("Pengeluaran")),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _tipe = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
            ElevatedButton(
              onPressed: () async {
                final deskripsi = _deskripsiCtrl.text.trim();
                final jumlah = double.tryParse(_jumlahCtrl.text.trim());
                if (deskripsi.isEmpty || jumlah == null) return;
                await FirebaseFirestore.instance.collection("catatan").doc(id).update({
                  "deskripsi": deskripsi,
                  "jumlah": jumlah,
                  "tipe": _tipe,
                });
                _deskripsiCtrl.clear();
                _jumlahCtrl.clear();
                Navigator.pop(context);
              },
              child: const Text("Simpan"),
            ),
          ],
        );
      },
    );
  }

  double _hitungSaldo(QuerySnapshot snapshot) {
    double total = 0;
    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final jumlah = (data["jumlah"] ?? 0.0).toDouble();
      final tipe = data["tipe"] ?? "Pemasukan";
      if (tipe == "Pemasukan") {
        total += jumlah;
      } else {
        total -= jumlah;
      }
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Catatan Keuangan"),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(12),
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  TextField(
                    controller: _deskripsiCtrl,
                    decoration: const InputDecoration(
                      labelText: "Deskripsi",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _jumlahCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Jumlah (Rp)",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButton<String>(
                          value: _tipe,
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(value: "Pemasukan", child: Text("Pemasukan")),
                            DropdownMenuItem(value: "Pengeluaran", child: Text("Pengeluaran")),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _tipe = val);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: _tambahCatatan,
                        icon: const Icon(Icons.add),
                        label: const Text("Tambah"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("catatan")
                  .orderBy("waktu", descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final saldo = _hitungSaldo(snapshot.data!);
                return Column(
                  children: [
                    Container(
                      width: double.infinity,
                      color: Colors.blue[50],
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        "Saldo Total: ${_rupiah.format(saldo)}",
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        children: snapshot.data!.docs.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final jumlah = (data["jumlah"] ?? 0.0).toDouble();
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            child: ListTile(
                              title: Text(data["deskripsi"] ?? ""),
                              subtitle: Text(data["tipe"] ?? ""),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 160,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      _rupiah.format(jumlah),
                                      style: TextStyle(
                                        color: data["tipe"] == "Pemasukan"
                                            ? Colors.green
                                            : Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.blue),
                                    onPressed: () => _editCatatan(
                                      doc.id,
                                      data["deskripsi"] ?? "",
                                      jumlah,
                                      data["tipe"] ?? "Pemasukan",
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _hapusCatatan(doc.id),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
