import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:metrox_po/api_service.dart';
import 'package:metrox_po/models/db_helper.dart';

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

  // Pagination variables
  int currentPage = 0;
  final int itemsPerPage = 10;

  @override
  void initState() {
    super.initState();
    loadLocalMasterItems(); // Load items from the local database on init
  }

  Future<void> loadLocalMasterItems() async {
    setState(() {
      isLoading = true;
    });

    try {
      final dbItems = await DatabaseHelper().getAllMasterItems();
      setState(() {
        items = dbItems;
        filteredItems = dbItems;
        currentPage = 0; // Reset to first page on load
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading local data: $e')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> clearMasterItems() async {
  try {
    await DatabaseHelper().clearMasterItems();
    setState(() {
      items.clear();
      filteredItems.clear(); // Clear the displayed items
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('All items cleared successfully')),
    );
  } catch (e) {
    print(e); // Log the actual error
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error clearing items: ${e.toString()}')),
    );
  }
}


  Future<void> deleteMasterItem(String itemSKU) async {
    try {
      await DatabaseHelper().deleteMasterItem(itemSKU);
      setState(() {
        items.removeWhere((item) => item['item_sku'] == itemSKU);
        filteredItems = items; // Update filtered items
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Item deleted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting item: $e')),
      );
    }
  }

  Future<void> fetchMasterItems(String brand) async {
    setState(() {
      isLoading = true;
    });

    try {
      await apiMaster.fetchAndSaveMasterItems(brand, (loading) {
        setState(() {
          isLoading = loading;
        });
      });
      await loadLocalMasterItems();
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
      setState(() {
        filteredItems = items; // Reset filtered items if search is empty
        currentPage = 0; // Reset to first page
      });
    }
  }

  List<Map<String, dynamic>> get paginatedItems {
    int startIndex = currentPage * itemsPerPage;
    int endIndex = startIndex + itemsPerPage;

    // Ensure we don't go out of bounds
    return filteredItems.sublist(startIndex,
        endIndex < filteredItems.length ? endIndex : filteredItems.length);
  }

  void nextPage() {
    if ((currentPage + 1) * itemsPerPage < filteredItems.length) {
      setState(() {
        currentPage++;
      });
    }
  }

  void previousPage() {
    if (currentPage > 0) {
      setState(() {
        currentPage--;
      });
    }
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
        inputFormatters: [UpperCaseTextFormatter()],

            ),
          ),
          ElevatedButton(
            onPressed: clearMasterItems,
            child: Text('Clear All Items'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red, // Change button color to red
            ),
          ),
          Expanded(
            child: isLoading
                ? Center(child: CircularProgressIndicator())
                : filteredItems.isEmpty
                    ? Center(child: Text('No master items found'))
                    : Column(
                        children: [
                          Expanded(
                           child: SingleChildScrollView(
                                scrollDirection: Axis.vertical,
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  columns: const [
                                    DataColumn(label: Text('ITEM SKU')),
                                    DataColumn(label: Text('ITEM SKU Name')),
                                    DataColumn(label: Text('Barcode')),
                                    DataColumn(label: Text('Vendor Barcode')),
                                    DataColumn(label: Text('Actions')),
                                  ],
                                  rows: paginatedItems.map((item) {
                                    return DataRow(
                                      cells: [
                                        DataCell(Text(item['item_sku'] ?? '')),
                                        DataCell(Text(item['item_name'] ?? '')),
                                        DataCell(Text(item['barcode'] ?? '')),
                                        DataCell(
                                            Text(item['vendor_barcode'] ?? '')),
                                        DataCell(
                                          IconButton(
                                            icon: Icon(Icons.delete),
                                            onPressed: () {
                                              _confirmDelete(item['item_sku']);
                                            },
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ),
                          // Pagination Controls
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              ElevatedButton(
                                onPressed: previousPage,
                                child: Text('Previous'),
                              ),
                              Text(
                                  'Page ${currentPage + 1} of ${((filteredItems.length / itemsPerPage).ceil())}'),
                              ElevatedButton(
                                onPressed: nextPage,
                                child: Text('Next'),
                              ),
                            ],
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(String itemSKU) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Confirmation'),
        content: Text('Are you sure you want to delete this item?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              deleteMasterItem(itemSKU); // Call the delete function
            },
            child: Text('Delete'),
          ),
        ],
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
