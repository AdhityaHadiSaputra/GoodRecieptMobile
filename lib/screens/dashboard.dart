import 'package:flutter/material.dart';
import 'package:metrox_po/screens/login_form.dart';


import '../utils/storage.dart';

class Authpage extends StatefulWidget {
  const Authpage({super.key});

  @override
  State<Authpage> createState() => _AuthpageState();
}

class _AuthpageState extends State<Authpage> {
  StorageService storageService = StorageService.instance;
  @override
  void initState() {
    init();
    super.initState();
  }

  void init() async {
    await storageService.initStorage();
  }

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      child: Scaffold(
        body: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 15,
            vertical: 15,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
               Align(
                    alignment: Alignment.topCenter,
                    child:Image(image: AssetImage('assets/logo.png'))),
                SizedBox(height: 30,),
                Align(
                  alignment: Alignment.center,
                  child: 
                Text(
                  "Login",
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                    
                  ),
                ),
                ),
                SizedBox(height: 50,),
      
                const LoginForm(),
            
              ],
            ),
          ),
        ),
      ),
    );
  }
}
