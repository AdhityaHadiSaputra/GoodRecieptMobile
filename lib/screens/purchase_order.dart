import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:metrox_po/drawer.dart';
import 'package:metrox_po/models/db_helper.dart';
import 'package:metrox_po/utils/list_extensions.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api_service.dart';

// ex: 10.0000 to 10
final formatQTYRegex = RegExp(r'([.]*0+)(?!.*\d)');

class AppointmentPage extends StatefulWidget {
  final Map<String, dynamic>? initialPOData;

  const AppointmentPage({super.key, this.initialPOData});

  @override
  State<AppointmentPage> createState() => _AppointmentPageState();
}

class _AppointmentPageState extends State<AppointmentPage> {
  final Apiuser apiuser = Apiuser();
  final DatabaseHelper dbHelper =
      DatabaseHelper(); // Replace with your API service
  List<Map<String, dynamic>> detailPOData = []; // Ensure this is initialized
  bool isLoading = false;
  final TextEditingController _poNumberController =
      TextEditingController(text: "PO/YEC/2409/0001");
  // TextEditingController();
  QRViewController? controller;
  String scannedBarcode = "";
  int scannedQtySum = 0;

  @override
  void initState() {
    super.initState();
    if (widget.initialPOData != null) {
      detailPOData = [widget.initialPOData!];
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  Future<void> fetchPOData(String pono) async {
    setState(() {
      isLoading = true;
    });

    try {
      final response = await apiuser.fetchPO(pono);
      // print('Response: ${jsonEncode(response)}'); // Debug print

      if (response.containsKey('code')) {
        final resultCode = response['code'];
        // print('Result Code: $resultCode'); // Debug print

        if (resultCode == "1") {
          final Map<String, dynamic> msg = response['msg'];
          final headerPO = msg['HeaderPO'];
          final List<Map<String, dynamic>> localPOs =
              await dbHelper.getPODetails(headerPO[0]['PONO']);
          final List<dynamic> detailPOList = msg['DetailPO'] as List<dynamic>;
          setState(() {
            // mapped from network to local pos
            detailPOData = detailPOList.map((item) {
              final product = localPOs.firstWhereOrNull(
                  (product) => product["barcode"] == item["BARCODE"]);
              if (product != null) {
                item["QTYD"] = product["qty_different"];
                item["QTYS"] = product["qty_scanned"];
              }

              return item as Map<String, dynamic>;
            }).toList();
          });
        } else {
          if (resultCode == "2") {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No data available for this PO')),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Request failed: $resultCode')),
            );
          }
          setState(() {
            detailPOData = [];
          });
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unexpected response format')),
        );
        setState(() {
          detailPOData = [];
        });
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching PO: $error')),
      );
      setState(() {
        detailPOData = [];
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> submitDataToDatabase() async {
    String poNumber = _poNumberController.text.trim();

    if (poNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please search for a PO before submitting data')),
      );
      return;
    }

    for (var item in detailPOData) {
      final poData = {
        'pono': poNumber, // Use the searched PO number here
        'item_sku': item['ITEMSKU'],
        'item_name': item['ITEMSKUNAME'],
        'barcode': item['BARCODE'],
        'qty_po': item['QTYPO'],
        'qty_scanned': item['QTYS'] ?? 0,
        'qty_different': item['QTYD'] ?? 0,
      };

      await dbHelper.insertOrUpdatePO(poData); // Insert the data to sqflite
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PO data saved to local database')),
    );
  }

  void _onQRViewCreated(QRViewController qrController) {
    setState(() {
      controller = qrController;
    });

    controller!.scannedDataStream.listen((scanData) {
      setState(() {
        scannedBarcode = scanData.code ?? "";
      });

      if (scannedBarcode.isNotEmpty) {
        checkAndSumQty(scannedBarcode);
      }
    });
    // checkAndSumQty("S54227417345002");
  }

  void checkAndSumQty(String scannedCode) {
    for (var item in detailPOData) {
      if (item['BARCODE'] == scannedCode) {
        _showQtyInputDialog(item);
        return;
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('No matching item found for scanned barcode')),
    );
  }

  void _showQtyInputDialog(Map<String, dynamic> item) {
    Navigator.of(context).pop();
    TextEditingController qtyController = TextEditingController(text: '');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Input Quantity for ${item['ITEMSKUNAME']}'),
          content: TextField(
            controller: qtyController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Quantity',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context)
                    .pop(); // Close dialog if Cancel is pressed
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                int inputQty = int.tryParse(qtyController.text) ?? 0;

                // if (inputQty > 0) {
                //   int poQty = int.tryParse((item['QTYPO'] as String)
                //           .replaceAll(formatQTYRegex, '')) ??
                //       0;
                //   if (inputQty <= poQty) {
                //     item['QTYS'] = inputQty;
                //     item['QTYD'] = inputQty != poQty ? poQty - inputQty : 0;
                //     updatePO(item);
                //   } else {
                //     ScaffoldMessenger.of(context).showSnackBar(
                //       const SnackBar(
                //           content: Text(
                //         "Quantity can't be larger than Quantity PO",
                //       )),
                //     );
                //   }
                // }
                if (inputQty > 0) {
                  int poQty = int.tryParse((item['QTYPO'] as String)
                          .replaceAll(formatQTYRegex, '')) ??
                      0;
                  bool isLargerThanQTYPO = inputQty > poQty;
                  item['QTYS'] = isLargerThanQTYPO ? poQty : inputQty;
                  item['QTYD'] =
                      isLargerThanQTYPO ? (poQty - inputQty).abs() : 0;
                  updatePO(item);
                }

                Navigator.of(context).pop(); // Close input dialog
              },
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
  }

  Future<void> updatePO(Map<String, dynamic> item) async {
    detailPOData = detailPOData.replaceOrAdd(
        item, (po) => po['BARCODE'] == item["BARCODE"]);
    setState(() {});
    savePOToRecent(_poNumberController.text);
    submitDataToDatabase();
  }

  Future<void> savePOToRecent(String updatedPONO) async {
    final prefs = await SharedPreferences.getInstance();
    List<String>? recentNoPOs = prefs.getStringList('recent_pos') ?? [];

    recentNoPOs =
        recentNoPOs.replaceOrAdd(updatedPONO, (pono) => pono == updatedPONO);
    await prefs.setStringList('recent_pos', recentNoPOs);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('PO Details'),
      ),
      drawer: const MyDrawer(), // Replace with your actual drawer widget
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _poNumberController,
                    decoration: const InputDecoration(
                      labelText: 'Enter PO Number',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () {
                    String poNumber = _poNumberController.text.trim();
                    if (poNumber.isNotEmpty) {
                      fetchPOData(poNumber);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Please enter a valid PO number')),
                      );
                    }
                  },
                  child: const Icon(Icons.search),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : detailPOData.isEmpty
                      ? const Center(
                          child: Text('Search for a PO to see details'))
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Column(
                            children: [
                              DataTable(
                                columns: const [
                                  DataColumn(label: Text('Item SKU')),
                                  DataColumn(label: Text('Item Name')),
                                  DataColumn(label: Text('Barcode')),
                                  DataColumn(label: Text('Qty PO')),
                                  DataColumn(label: Text('Qty Scanned')),
                                  DataColumn(label: Text('Qty Different')),
                                ],
                                rows: detailPOData
                                    .map(
                                      (e) => DataRow(cells: [
                                        DataCell(Text(
                                            e['ITEMSKU']?.toString() ?? '')),
                                        DataCell(Text(
                                            e['ITEMSKUNAME']?.toString() ??
                                                '')),
                                        DataCell(Text(
                                            e['BARCODE']?.toString() ?? '')),
                                        DataCell(
                                            Text(e['QTYPO']?.toString() ?? '')),
                                        DataCell(
                                            Text(e['QTYS']?.toString() ?? '0')),
                                        DataCell(
                                            Text((e['QTYD'] ?? 0).toString())),
                                      ]),
                                    )
                                    .toList(),
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => QRViewExample(
                                        onQRViewCreated: _onQRViewCreated,
                                        onScanComplete: () {},
                                        // onScanComplete: () {
                                        //   if (detailPOData.isNotEmpty) {
                                        //     for (var item in detailPOData) {
                                        //       if (item['QTYS'] != null &&
                                        //           item['QTYS'] > 0) {
                                        //         addPOToRecent(item);
                                        //       }
                                        //     }
                                        //   }
                                        // },
                                      ),
                                    ),
                                  ).then((_) {
                                    // Optionally reload data or do other actions after scanning is complete
                                  });
                                },
                                child: const Text('Scan QR Code'),
                              ),
                              // !AUTO SAVE PO WHEN SCANNED
                              // ElevatedButton(
                              //   onPressed:
                              //       submitDataToDatabase, // Call the submit function
                              //   child: const Column(
                              //     children: [
                              //       Icon(Icons.save),
                              //       Text('Submit Data')
                              //     ],
                              //   ),
                              // ),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class QRViewExample extends StatelessWidget {
  final void Function(QRViewController) onQRViewCreated;
  final VoidCallback onScanComplete;

  const QRViewExample(
      {super.key, required this.onQRViewCreated, required this.onScanComplete});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan QR Code')),
      body: QRView(
        key: GlobalKey(debugLabel: 'QR'),
        onQRViewCreated: (controller) {
          onQRViewCreated(controller);
        },
        overlay: QrScannerOverlayShape(
          borderColor: Colors.red,
          borderRadius: 10,
          borderLength: 30,
          borderWidth: 10,
          cutOutSize: 300,
        ),
      ),
    );
  }
}
