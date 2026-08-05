import 'package:flutter/material.dart';

void main() {
  runApp(const easy_attendance());

}

class easy_attendance extends StatelessWidget{
  const easy_attendance({super.key});

  @override
  Widget build(BuildContext context){
    return MaterialApp(
      title: 'Attendance Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontSize: 18),
          bodyMedium: TextStyle(fontSize: 16),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget{
  const HomeScreen({super.key});
  
  @override
  Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Attendance Tracker',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          )
        ),
        centerTitle:true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment:MainAxisAlignment.center,
          children:[
            _buildHomeButton(
              context,
              icon: Icons.people,
              label: 'Employees',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Attendance screen coming soon!')),
                );
              },
            ),
            const SizedBox(height: 20),
            _buildHomeButton(
              context,
              icon: Icons.receipt_long,
              label: 'Reports',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Report Screen Coming Soon!')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeButton(  
      BuildContext context, {
      required IconData icon,
      required String label,
      required VoidCallback onTap,    
      }) {
        return SizedBox(
          width: double.infinity,
          height: 80,
          child: ElevatedButton.icon(
            onPressed: onTap,
            icon: Icon(icon, size: 32),
            label: Text(
              label,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 24),
            ),
          ),
        );
  }
}