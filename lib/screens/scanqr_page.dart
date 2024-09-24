import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:metrox_po/drawer.dart';
import 'package:metrox_po/models/db_helper.dart';
import 'package:metrox_po/utils/list_extensions.dart';
import 'package:metrox_po/utils/storage.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api_service.dart';

final formatQTYRegex = RegExp(r'([.]*0+)(?!.*\d)');

class ScanQRPage extends StatefulWidget {
  final Map<String, dynamic>? initialPOData;

  const ScanQRPage({super.key, this.initialPOData});

  @override
  State<ScanQRPage> createState() => _ScanQRPageState();
}

class _ScanQRPageState extends State<ScanQRPage> {
  final Apiuser apiuser = Apiuser();
  final StorageService storageService = StorageService.instance;
  final ApiService apiservice = ApiService();
  final DatabaseHelper dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> detailPOData = [];
  List<Map<String, dynamic>> detailPODataScan = [];
  List<Map<String, dynamic>> notInPOItems =[]; 
  List<Map<String, dynamic>> scannedResults = []; 
  List<Map<String, dynamic>> differentScannedResults =[]; 
  bool isLoading = false;
  final TextEditingController _poNumberController =TextEditingController();
      //TextEditingController(text: "PO/YEC/2409/0001");
   final TextEditingController _koliController = TextEditingController(); 
  QRViewController? controller;
  String scannedBarcode = "";
  late String userId = '';

  final AudioPlayer _audioPlayer = AudioPlayer();

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
    _audioPlayer.dispose(); 
    super.dispose();
  }

  void playBeep() async {
    await _audioPlayer.play(AssetSource('beep.mp3'));
  }

  Future<void> fetchPOData(String pono) async {
    setState(() => isLoading = true);
    try {
      final userData = storageService.get(StorageKeys.USER);
      final response = await apiservice.loginUser(
        userData['USERID'],
        userData['USERPASSWORD'],
      );
      if (response.containsKey('code')) {
        final resultCode = response['code'];

        setState(() {
          if (resultCode == "1") {
            final List<dynamic> msgList = response['msg'];
            if (msgList.isNotEmpty && msgList[0] is Map<String, dynamic>) {
              final Map<String, dynamic> msgMap =
                  msgList[0] as Map<String, dynamic>;
              userId = msgMap[
                  'USERID'];
            }
          } else {
            print('Request failed with code $resultCode');
            print(response["msg"]);
          }
        });
      } else {
        print('Unexpected response structure');
      }
    } catch (error) {
      print('Error: $error');
    }
    try {
      final response = await apiuser.fetchPO(pono);

      if (response.containsKey('code') && response['code'] == '1') {
        final msg = response['msg'];
        final headerPO = msg['HeaderPO'];
        final localPOs =
            await dbHelper.getPOScannedODetails(headerPO[0]['PONO']);
        final scannedPOs =
            await dbHelper.getPOResultScannedDetails(headerPO[0]['PONO']);
        final differentPOs =
            await dbHelper.getPODifferentScannedDetails(headerPO[0]['PONO']);

        scannedResults = [...scannedPOs];
        differentScannedResults = [...differentPOs];
        final detailPOList = List<Map<String, dynamic>>.from(msg['DetailPO']);

        setState(() {
          detailPOData = detailPOList.map((item) {
            final product = localPOs.firstWhereOrNull((product) =>
                product["barcode"] == item["BARCODE"] ||
                product["barcode"] == item["BARCODE"]);
            if (product != null) {
              item["QTYD"] = product["qty_different"];
              item["QTYS"] = scannedPOs.isNotEmpty
                  ? scannedPOs.length
                  : product["qty_scanned"];
            }
            return item;
          }).toList();
        });
      } else {
        _showErrorSnackBar('Request failed: ${response['code']}');
      }
    } catch (error) {
      _showErrorSnackBar('Error fetching PO: $error');
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
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

    final deviceInfoPlugin = DeviceInfoPlugin();
    String deviceName = '';

    if (GetPlatform.isAndroid) {
      final androidInfo = await deviceInfoPlugin.androidInfo;
      deviceName = '${androidInfo.brand} ${androidInfo.model}';
    } else if (GetPlatform.isIOS) {
      final iosInfo = await deviceInfoPlugin.iosInfo;
      deviceName = '${iosInfo.name} ${iosInfo.systemVersion}';
    } else {
      deviceName = 'Unknown Device';
    }

    String scandate = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

    for (var item in detailPOData) {
      final poData = {
        'pono': poNumber,
        'item_sku': item['ITEMSKU'],
        'item_name': item['ITEMSKUNAME'],
        'barcode': item['BARCODE'],
        'qty_po': item['QTYPO'],
        'qty_scanned': item['QTYS'] ?? 0,
        'qty_different': item['QTYD'] ?? 0,
        'device_name': deviceName,
        'scandate': scandate,
        // "status":
        //     item['QTYD'] != null && item['QTYD'] != 0 ? "different" : "scanned"
      };

      await dbHelper.insertOrUpdatePO(poData);
    }
    // !UNCOMMENT THIS CODE
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PO data saved')),
    );
  }

  void _onQRViewCreated(QRViewController qrController) {
    setState(() {
      controller = qrController;
    });

    controller!.scannedDataStream.listen((scanData) async {
      setState(() {
        scannedBarcode = scanData.code ?? "";
      });

      if (scannedBarcode.isNotEmpty) {
        playBeep();
        controller?.pauseCamera();
        await checkAndSumQty(scannedBarcode);
        Future.delayed(const Duration(seconds: 1), () {
          controller?.resumeCamera();
        });
      }
    });
  }

  Future<void> checkAndSumQty(String scannedCode) async {
    final item = detailPOData.firstWhereOrNull(
      (item) =>
          item['BARCODE'] == scannedCode ||
          item['ITEMSKU'] == scannedCode ||
          item['VENDORBARCODE'] == scannedCode,
    );
    final deviceInfoPlugin = DeviceInfoPlugin();
    String deviceName = '';

    if (GetPlatform.isAndroid) {
      final androidInfo = await deviceInfoPlugin.androidInfo;
      deviceName = '${androidInfo.brand} ${androidInfo.model}';
    } else if (GetPlatform.isIOS) {
      final iosInfo = await deviceInfoPlugin.iosInfo;
      deviceName = '${iosInfo.name} ${iosInfo.systemVersion}';
    } else {
      deviceName = 'Unknown Device';
    }

    if (item != null) {
      int poQty = int.tryParse((item['QTYPO'] as String).replaceAll(formatQTYRegex, '')) ?? 0;
      int scannedQty = scannedResults.isNotEmpty
          ? scannedResults.length
          : int.tryParse(item['QTYS']?.toString() ?? '0') ?? 0;
      int currentQtyD = int.tryParse(item['QTYD']?.toString() ?? '0') ?? 0;

      int newScannedQty = scannedQty + 1;

      item['QTYS'] = newScannedQty > poQty ? poQty : newScannedQty;
      item['QTYD'] = currentQtyD != 0
          ? currentQtyD + 1
          : newScannedQty > poQty
              ? newScannedQty - poQty
              : 0;

      item['scandate'] = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
      // Add to scanned results
      setState(() {}); // Update UI

      final mappedPO = {
        'pono': _poNumberController.text.trim(),
        'item_sku': item['ITEMSKU'],
        'item_name': item['ITEMSKUNAME'],
        'barcode': scannedCode,
        'qty_po': item['QTYPO'],
        'qty_scanned': 1,
        'qty_different': currentQtyD,
        'device_name': deviceName,
        'scandate': item['scandate'],
        'user': userId,
        'qty_koli': int.tryParse(_koliController.text.trim()) ?? 0, // Add koli quantity
        "status": item['QTYD'] != 0 ? "different" : 'scanned',
        "type": scannedPOType
      };

      if (scannedQty < poQty) {
        scannedResults.add(mappedPO);
      } else {
        // differentScannedResults.add(mappedPO);
      }

      await Future.wait([
        updatePO(item),
        submitScannedResults(),
      ]);
    } else {
      final masterItem = await fetchMasterItem(scannedCode);
      if (masterItem != null) {
        handleMasterItemScanned(masterItem, scannedCode);
      } else {
        _showErrorSnackBar('No matching item found in master item table');
      }
    }
  }

  void handleMasterItemScanned(
      Map<String, dynamic> masterItem, String scannedCode) {
    final existingItem =
        notInPOItems.firstWhereOrNull((e) => e['VENDORBARCODE'] == scannedCode);

    if (existingItem != null) {
      int scannedQty =
          int.tryParse(existingItem['QTYS']?.toString() ?? '0') ?? 0;
      existingItem['QTYS'] = scannedQty + 1; // Increment for not in PO items
      existingItem['scandate'] =
          DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    } else {
      masterItem['QTYS'] = 1; // New item
      masterItem['scandate'] =
          DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
      notInPOItems.add(masterItem);
    }
    setState(() {}); // Update UI
  }

  Future<void> submitScannedResults() async {
    final allPOs = [...scannedResults, ...differentScannedResults];
    for (var result in allPOs) {
      await dbHelper.insertOrUpdateScannedResults(
          result); // Assuming you have a method for this
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Scanned results saved successfully')),
    );
  }

 Future<Map<String, dynamic>?> fetchMasterItem(String scannedCode) async {
    const url = 'http://108.136.252.63:8080/pogr/getmaster.php';
    const brand = 'YEC';
    try {
        var request = http.MultipartRequest('POST', Uri.parse(url));
        request.fields['ACTION'] = 'GETITEM';
        request.fields['BRAND'] = brand;
        request.fields['VENDORBARCODE'] = scannedCode;

        print('Sending request with:');
        print('ACTION: GETITEM');
        print('BRAND: $brand');
        print('VENDORBARCODE: $scannedCode');

        var response = await request.send();

        if (response.statusCode == 200) {
            var responseData = await response.stream.bytesToString();
            print('Response data: $responseData'); // Tambahkan ini
            var jsonResponse = json.decode(responseData);

            if (jsonResponse['code'] == '1' && jsonResponse['msg'] is List) {
                List<dynamic> itemList = jsonResponse['msg'];
                if (itemList.isNotEmpty) {
                    var item = itemList.first as Map<String, dynamic>;
                    item['scandate'] = DateTime.now(); // Tambahkan scandate
                    return item;
                } else {
                    print('No items found in response');
                }
            } else {
                print('Unexpected response format: $jsonResponse');
            }
        } else {
            print('Request failed with status: ${response.statusCode}');
        }
        return null;
    } catch (error) {
        _showErrorSnackBar('Error fetching master item: $error');
        return null;
    }
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
        drawer: const MyDrawer(),
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
                      inputFormatters: [UpperCaseTextFormatter()],
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
                            content: Text('Please enter a valid PO number'),
                          ),
                        );
                      }
                    },
                    child: const Icon(Icons.search),
                  ),
                ],
              ),
               const SizedBox(height: 20),
            TextFormField(
              controller: _koliController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Enter Koli Quantity',
                border: OutlineInputBorder(),
              ),
            ),
              const SizedBox(height: 20),
              isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Expanded(
                      child: Column(
                        children: [
                          if (detailPOData.isEmpty)
                            const Center(
                                child: Text('Search for a PO to see details'))
                          else
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.vertical,
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: DataTable(
                                    columns: const [
                                      DataColumn(label: Text('Item SKU')),
                                      DataColumn(label: Text('Item Name')),
                                      DataColumn(label: Text('Barcode')),
                                      DataColumn(label: Text('Qty PO')),
                                      DataColumn(label: Text('Qty Scan')),
                                      DataColumn(label: Text('Qty Diff')),

                                    ],
                                    rows: detailPOData
                                        .map(
                                          (e) => DataRow(
                                            cells: [
                                            DataCell(Text(
                                                  e['ITEMSKU']?.toString() ??
                                                      '')),
                                            DataCell(Text(e['ITEMSKUNAME']
                                                      ?.toString() ??
                                                  '')),
                                            DataCell(Text(
                                                  e['BARCODE']?.toString() ??
                                                      '')),
                                            DataCell(Text((e['QTYPO'] as String).replaceAll(formatQTYRegex, ''))),
                                            DataCell(Text(e['QTYS']?.toString() ?? '0')), // Scanned quantity
                                            DataCell(Text(e['QTYD']?.toString() ?? '0')), // Quantity difference
                                            ],
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(height: 20),
                          Expanded(
                            child: Column(
                              children: [
                                const Text(
                                  'Scanned Results',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold),
                                ),
                                Expanded(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            controller: ScrollController(),
            child: DataTable(
              columns: const [
                DataColumn(label: Text('PO Number')),
                DataColumn(label: Text('Item SKU')),
                DataColumn(label: Text('Item Name')),
                DataColumn(label: Text('Barcode')),
                DataColumn(label: Text('Qty Scanned')),
                DataColumn(label: Text('User')),
                DataColumn(label: Text('Device')),
                DataColumn(label: Text('QTY Koli')),
                DataColumn(label: Text('Timestamp')),
             
              ],
              rows: [
                ...scannedResults.map(
                  (result) => DataRow(
                    cells: [
                      DataCell(Text(result['pono'] ?? '')),
                      DataCell(Text(result['item_sku'] ?? '')),
                      DataCell(Text(result['item_name'] ?? '')),
                      DataCell(Text(result['barcode'] ?? '')),
                      DataCell(Text(result['qty_scanned'].toString())),
                      DataCell(Text(result['user'] ?? '')),
                      DataCell(Text(result['device_name'] ?? '')),
                      DataCell(Text(result['qty_koli'].toString())),
                      DataCell(Text(result['scandate'] ?? '')),
                     
                    ],
                  ),
                ),
                ...differentScannedResults.map(
                  (result) => DataRow(
                    cells: [
                      DataCell(Text(result['pono'] ?? '')),
                      DataCell(Text(result['item_sku'] ?? '')),
                      DataCell(Text(result['item_name'] ?? '')),
                      DataCell(Text(result['barcode'] ?? '')),
                      DataCell(Text(result['qty_scanned'].toString())),
                      DataCell(Text(result['user'] ?? '')),
                      DataCell(Text(result['device_name'] ?? '')),
                      DataCell(Text(result['qty_koli'].toString())),
                      DataCell(Text(result['scandate'] ?? '')),
                     
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 20),
      ElevatedButton(
        onPressed: () {
          if (_poNumberController.text.trim().isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Please enter a PO number before scanning.'),
              ),
            );
            return;
          }
          if (_koliController.text.trim().isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Please enter koli quantity before scanning'),
              ),
            );
            return;
          }

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => QRViewExample(
                onQRViewCreated: _onQRViewCreated,
                onScanComplete: () {},
              ),
            ),
          ).then((_) {
          });
        },
        child: const Text('Scan QR Code'),
      ),
    ],
  ),
)
                        ]
                  )
          )
            ]
    )
        )
    );
  }
}

class QRViewExample extends StatelessWidget {
  final void Function(QRViewController) onQRViewCreated;
  final VoidCallback onScanComplete;

  const QRViewExample({
    super.key,
    required this.onQRViewCreated,
    required this.onScanComplete,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan QR Code')),
      body: QRView(
        key: GlobalKey(debugLabel: 'QR'),
        onQRViewCreated: onQRViewCreated,
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

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
