
import 'package:flutter/material.dart';
import 'package:metrox_po/screens/dashboard.dart';

import 'package:metrox_po/screens/detail/master_item.dart';
// import 'package:metrox_po/screens/purchase_order.dart';
import 'package:metrox_po/screens/recent_po.dart';

import 'package:metrox_po/screens/scanqr_page.dart';

import 'package:metrox_po/utils/storage.dart';

import 'api_service.dart';

class MyDrawer extends StatefulWidget {
  const MyDrawer({super.key});

  @override
  _MyDrawerState createState() => _MyDrawerState();
}

class _MyDrawerState extends State<MyDrawer> {
  final ApiService apiuser = ApiService();
  final StorageService storageService = StorageService.instance;
  late String userId = '';
  late String JobId = '';
  

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<void> fetchData() async {
    try {
      final userData = storageService.get(StorageKeys.USER);
      final response = await apiuser.loginUser(
        userData['USERID'],
        userData['USERPASSWORD'],
      );
      print(response);

      // Check if the response is not null and contains a 'code' field
      if (response.containsKey('code')) {
        final resultCode = response['code'];

        setState(() {
          // Check the 'code' to determine if the request was successful
          if (resultCode == "1") {
            // Extract USERID from the response and set it in the state
            final List<dynamic> msgList = response['msg'];
            if (msgList.isNotEmpty && msgList[0] is Map<String, dynamic>) {
              final Map<String, dynamic> msgMap =
                  msgList[0] as Map<String, dynamic>;
              userId = msgMap[
                  'USERID']; // Assuming USERID is in the first map of the list
            }
          } else {
            // Handle the case where the request was not successful
            print('Request failed with code $resultCode');
            print(response["msg"]);
          }
        });
      } else {
        // Handle the case where the response structure is unexpected
        print('Unexpected response structure');
      }
    } catch (error) {
      // Handle error, e.g., display an error message to the user
      print('Error: $error');
    }
  }

  Future<void> _showLogoutConfirmationDialog(BuildContext context) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Logout Confirmation'),
          content: const Text('Are you sure you want to logout?'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the pop-up
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const Authpage()),
                  (route) => false,
                );
              },
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
   
    return SizedBox(
      child: Drawer(
        child: WillPopScope(
          onWillPop: () async {
            await _showLogoutConfirmationDialog(context);
            return false;
          },
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              
              UserAccountsDrawerHeader(
                accountName: const Text(""),
                
                accountEmail: Row(
                  children: [
                    const Icon(
                      Icons.person,
                      color: Color.fromARGB(255, 255, 255, 255),
                    ),
                    const SizedBox(width: 20),
                    Text(
                      userId,
                      style: const TextStyle(
                        color: Color.fromARGB(255, 255, 255, 255),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Times New Roman',
                      ),
                    ),
                    SizedBox(height: 10,)
                  ],
                  
                ),
                
                decoration: const BoxDecoration(
                  
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
                  image: DecorationImage(
                    image: AssetImage('assets/gr2.png'), fit: BoxFit.fill 
                  ),
                ),
              ), 
            
              // ListTile(
              //   leading: Icon(Icons.payments_outlined),
              //   title: const Text("Purchase Order"),
              //   onTap: () {
              //      Navigator.pop(context); // Close the drawer
              //     Navigator.push(
              //       context,
              //       MaterialPageRoute(builder: (context) => AppointmentPage()),
              //     );
              //   },
              // ),
              ListTile(
                leading: Icon(Icons.document_scanner),
                title: const Text("Scan PO"),
                onTap: () {
                   Navigator.pop(context); // Close the drawer
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ScanQRPage()),
                  );
                },
              ),
               
               ListTile(
                leading: Icon(Icons.article),
                title: const Text("Master Item"),
                onTap: () {
                   Navigator.pop(context); // Close the drawer
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => MasterItemPage()),
                  );
                },
              ),
              
              ListTile(
                leading: Icon(Icons.history),
                title: const Text("Recent PO"),
                onTap: () {
                   Navigator.pop(context); // Close the drawer
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => RecentPOPage()),
                  );
                },
              ),
               
             
              const Divider(),
              
              ListTile(
                leading: Icon(Icons.logout),
                title: const Text("LogOut"),
                onTap: () {
                  _showLogoutConfirmationDialog(context);
                },
              ),
              // SwitchListTile(
              //   title: Text(
              //     isDarkMode ? 'Dark Mode' : 'Light Mode',
              //     style: TextStyle(
              //       color: isDarkMode ? Colors.white : Colors.black,
              //     ),
              //   ),
              //   value: isDarkMode,
              //   onChanged: (value) {
              //     final provider =
              //         Provider.of<ThemeProvider>(context, listen: false);
              //     provider
              //         .setTheme(value ? ThemeData.dark() : ThemeData.light());
              //   },
              //   activeColor: Colors.black,
              //   inactiveTrackColor: Colors.grey,
              // ),
            ],
          ),
        ),
      ),
    );
  }
}
