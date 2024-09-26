// import 'package:Refresh/drawer.dart';
import 'drawer.dart';
import 'package:flutter/material.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({Key? key}) : super(key: key);

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int currentPage = 0;
  final PageController _pageController = PageController();

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Logika logout saat tombol back ditekan
        // Pastikan untuk membersihkan sesi atau informasi pengguna yang diperlukan
        // Misalnya, Anda bisa memanggil fungsi logout di sini
        // Jangan lupa untuk mengatur Navigator.pop jika diperlukan
        return false; // Setel ke false jika Anda ingin mengizinkan tombol back
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Dashboard'),
        ),
        drawer: MyDrawer(),
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Background Image
            Image.asset(
              'assets/MOBILE2.png',
              fit: BoxFit.contain,
            ),
            // PageView
            PageView(
              controller: _pageController,
              onPageChanged: ((value) {
                setState(() {
                  currentPage = value;
                });
              }),
            ),
          ],
        ),
      ),
    );
  }
}
