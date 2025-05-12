import 'package:flutter/material.dart';

class Students extends StatefulWidget {
  const Students({super.key});

  @override
  State<Students> createState() => _StudentsState();
}

class _StudentsState extends State<Students> {
  final ScrollController _scrollController =
      ScrollController(); // ✅ Create ScrollController

  @override
  void dispose() {
    _scrollController.dispose(); // ✅ Dispose it to prevent memory leaks
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      endDrawer: Drawer(
        width: 1500,
        child: Column(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  'Image Drawer',
                  style: TextStyle(fontSize: 20, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        shrinkWrap: true,
        children: [
          // Static Header Row
          Row(
            children: [
              Expanded(
                flex: 1,
                child: Container(
                  margin: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Column(
                    children: [
                      Text('Underlines', style: TextStyle(fontSize: 20)),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Container(
                  margin: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Column(
                    children: [
                      Text('Underlines', style: TextStyle(fontSize: 20)),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Scrollable Container with Fixed Height
          Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  spreadRadius: 2,
                ),
              ],
            ),
            height: 600, // ✅ Fixed height for scrolling inside this container
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.all(10),
                  child: Text(
                    "Student List",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                const Divider(),

                // ✅ Scrollbar with ScrollController
                Expanded(
                  child: Scrollbar(
                    controller: _scrollController, // ✅ Assign ScrollController
                    thickness: 8, // Optional: For desktop apps
                    radius: const Radius.circular(10),
                    child: ListView.builder(
                      controller:
                          _scrollController, // ✅ Assign ScrollController
                      itemCount: 90,
                      itemBuilder: (context, index) {
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                          ),
                          trailing: SizedBox(
                            width: 279,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Expanded(
                                  child: TextButton(
                                    onPressed: () {},
                                    child: const Text(
                                      'Accept',
                                      style: TextStyle(
                                        color: Colors.green,
                                        fontSize: 20,
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: TextButton(
                                    onPressed: () {},
                                    child: const Text(
                                      'Delete',
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontSize: 20,
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: TextButton(
                                    onPressed: () {
                                      Scaffold.of(context).openEndDrawer();
                                    },
                                    child: const Text(
                                      'View',
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: 20,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          title: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircleAvatar(
                                radius: 20,
                                backgroundColor: Colors.amber,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: const [
                                    Text(
                                      'androidsdsd3@gmail.com',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text('sohaibshs'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
