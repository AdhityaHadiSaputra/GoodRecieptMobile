
import 'package:audioplayers/audioplayers.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

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
  List<Map<String, dynamic>> noitemScannedResults =[]; 
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
        final noitemScanned =
            await dbHelper.getPONOItemsScannedDetails(headerPO[0]['PONO']);

        scannedResults = [...scannedPOs];
        differentScannedResults = [...differentPOs];
        noitemScannedResults = [...noitemScanned];
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

  // Try finding the item in the existing PO data
  final itemInPO = detailPOData.firstWhereOrNull(
    (item) => 
        item['BARCODE'] == scannedCode || 
        item['ITEMSKU'] == scannedCode || 
        item['VENDORBARCODE'] == scannedCode
  );

  if (itemInPO != null) {
    // Calculate quantities
    int poQty = int.tryParse((itemInPO['QTYPO'] as String).replaceAll(formatQTYRegex, '')) ?? 0;
    int scannedQty = scannedResults.isNotEmpty
        ? scannedResults.length
        : int.tryParse(itemInPO['QTYS']?.toString() ?? '0') ?? 0;
    int currentQtyD = int.tryParse(itemInPO['QTYD']?.toString() ?? '0') ?? 0;

    print("PO Qty: $poQty, Scanned Qty: $scannedQty, Current QtyD: $currentQtyD");

    int newScannedQty = 1;

    itemInPO['QTYS'] = newScannedQty > poQty ? poQty : newScannedQty;
    itemInPO['QTYD'] = currentQtyD != 0
        ? currentQtyD + 1
        : newScannedQty > poQty
            ? newScannedQty - poQty
            : 0;

    itemInPO['scandate'] = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    setState(() {});

    final mappedPO = {
      'pono': _poNumberController.text.trim(),
      'item_sku': itemInPO['ITEMSKU'],
      'item_name': itemInPO['ITEMSKUNAME'],
      'barcode': scannedCode,
      'qty_po': itemInPO['QTYPO'],
      'qty_scanned': newScannedQty,
      'qty_different': itemInPO['QTYD'],
      'device_name': deviceName,
      'scandate': itemInPO['scandate'],
      'user': userId,
      'qty_koli': int.tryParse(_koliController.text.trim()) ?? 0,
      'status': itemInPO['QTYD'] != 0 ? 'different' : 'scanned',
      'type': scannedPOType,
    };

    if (scannedQty < poQty) {
      scannedResults.add(mappedPO);
    } else {
      print("Scanned qty exceeds PO qty.");
    }

    // Update the item in the PO and submit results
    await Future.wait([
      updatePO(itemInPO),
      submitScannedResults(),
    ]);
  } else {
    // If item not found in PO, check master items and handle accordingly
    final masterItem = await fetchMasterItem(scannedCode);
    print("Master item fetched: $masterItem");

    if (masterItem != null) {
      final mappedMasterItem = {
        'pono': _poNumberController.text.trim(),
        'item_sku': masterItem['item_sku'],
        'item_name': masterItem['item_name'],
        'barcode': scannedCode,
        'qty_po': 0, 
        'qty_scanned': 1,
        'qty_different': 0, 
        'device_name': deviceName,
        'scandate': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
        'user': userId,
        'qty_koli': int.tryParse(_koliController.text.trim()) ?? 0,
        'status': 'new',
        'type': scannedPOType,
      };

      scannedResults.add(mappedMasterItem);
      setState(() {});
      await submitScannedResults();
    } else {
      // If item not found in both PO and Master items, prompt for manual input
      final itemName = await _promptManualItemNameInput(scannedCode);

      if (itemName != null && itemName.isNotEmpty) {
        final manualMasterItem = {
          'pono': _poNumberController.text.trim(),
          'item_sku': '', // Using scannedCode as SKU, you can change this as needed
          'item_name': itemName,
          'barcode': scannedCode,
          'qty_po': 0,
          'qty_scanned': 1,
          'qty_different': 0,
          'device_name': deviceName,
          'scandate': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
          'user': userId,
          'qty_koli': int.tryParse(_koliController.text.trim()) ?? 0,
          'status': 'manual', // Indicate that this was manually added
          'type': scannedPOType,
        };

        noitemScannedResults.add(manualMasterItem);
        setState(() {});
        await submitScannedNoItemsResults();
      } else {
        print("Manual item name input was cancelled.");
      }
    }
  }
}

// Function to prompt for manual item name input
Future<String?> _promptManualItemNameInput(String scannedCode) async {
   
  return showDialog<String>(
    context: context,
    builder: (BuildContext context) {
      String itemName = '';

      return AlertDialog(
        title: Text('Enter Item Name'),
        content: TextField(
          onChanged: (value) {
            itemName = value.trim();
          },
          decoration: InputDecoration(
            labelText: 'Item Name',
            hintText: 'Enter the name for item $scannedCode',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(null);
            },
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(itemName);
            },
            child: Text('Save'),
          ),
        ],
      );
    },
  );
}

  Future<void> submitScannedResults() async {
    final allPOs = [...scannedResults, ...differentScannedResults, ...noitemScannedResults];
    for (var result in allPOs) {
      await dbHelper.insertOrUpdateScannedResults(
          result); // Assuming you have a method for this
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Scanned results saved successfully')),
    );
  }
  Future<void> submitScannedNoItemsResults() async {
    final allPOs = [...noitemScannedResults];
    for (var result in allPOs) {
      await dbHelper.insertOrUpdateScannedNoItemsResults(
          result); // Assuming you have a method for this
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Scanned No Item results saved successfully')),
    );
  }

Future<Map<String, dynamic>?> fetchMasterItem(String scannedCode) async {
  final db = await DatabaseHelper().database;
  final result = await db.query(
    'master_item',
    where: 'barcode = ? OR item_sku = ? OR vendor_barcode = ?',
    whereArgs: [scannedCode, scannedCode, scannedCode],
  );

  if (result.isNotEmpty) {
    print("Fetched data from database: $result"); // Check if this contains the required fields
    return result.first;
  } else {
    print("No data found for the scanned code: $scannedCode");
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
                ...noitemScannedResults.map(
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
