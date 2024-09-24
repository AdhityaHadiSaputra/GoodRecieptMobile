import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:metrox_po/api_service.dart';
import 'dart:convert';


class MasterItemPage extends StatefulWidget {
  @override
  _MasterItemPageState createState() => _MasterItemPageState();
}

class _MasterItemPageState extends State<MasterItemPage> {
  final ApiMaster apiMaster = ApiMaster();
  List<Map<String, dynamic>> items = [];
  List<Map<String, dynamic>> filteredItems = [];
  bool isLoading = false;
  TextEditingController searchController = TextEditingController();

  Future<void> fetchMasterItems(String brand) async {
    setState(() {
      isLoading = true;
    });

    try {
      Map<String, dynamic> data = await apiMaster.fetchMaster(brand);
      if (data['code'] == '1' && data['msg'] is List) {
        setState(() {
          items = List<Map<String, dynamic>>.from(data['msg']);
          filteredItems = items; // Initialize filteredItems with all items
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load master items')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void searchItems() {
    final searchQuery = searchController.text.trim();
    if (searchQuery.isNotEmpty) {
      fetchMasterItems(searchQuery);
    } else {
      setState(() => filteredItems = []);
    }
  }

  void _selectItem(Map<String, dynamic> item) {
    Navigator.of(context).pop(item);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Master Items'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                labelText: 'Search by Brand',
                border: OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(Icons.search),
                  onPressed: searchItems,
                ),
              ),
              onSubmitted: (_) => searchItems(),
            ),
          ),
          Expanded(
            child: isLoading
                ? Center(child: CircularProgressIndicator())
                : filteredItems.isEmpty && !isLoading
                    ? Center(child: Text('No master items found'))
                    : SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: Column(
                          children: [
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                columns: const [
                                  DataColumn(label: Text('ITEM SKU')),
                                  DataColumn(label: Text('ITEM SKU Name')),
                                  DataColumn(label: Text('Barcode')),
                                  DataColumn(label: Text('Vendor Barcode')),
                                ],
                                rows: filteredItems.map((item) {
                                  return DataRow(
                                    cells: [
                                      DataCell(Text(item['ITEMSKU'] ?? '')),
                                      DataCell(Text(item['ITEMSKUNAME'] ?? '')),
                                      DataCell(Text(item['BARCODE'] ?? '')),
                                      DataCell(Text(item['VENDORBARCODE'] ?? '')),
                                    ],
                                    onSelectChanged: (_) => _selectItem(item),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}


class ApiMaster {
  Future<Map<String, dynamic>> fetchMaster(String brand) async {
    try {
      final response = await http.post(
        Uri.parse(APIUrl.MASTER_URL),
        body: {
          'ACTION': 'GETITEM',
          'BRAND': brand,
        },
      );
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Failed to load Master Data');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }
}
