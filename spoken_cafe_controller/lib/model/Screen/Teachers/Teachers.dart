import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:spoken_cafe_controller/model/Screen/Teachers/Teacher_Posts/Teacher_posts.dart';

class Teachers extends StatefulWidget {
  const Teachers({super.key});

  @override
  State<Teachers> createState() => _TeachersState();
}

class _TeachersState extends State<Teachers> {
  final ScrollController _scrollController = ScrollController();
  bool _showPostsPage = false;
  bool _showGalleryPage = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _pickeFile() async {
    try {
      WidgetsFlutterBinding.ensureInitialized(); // Ensure Flutter is initialized
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );

      if (result != null) {
        PlatformFile file = result.files.first;
        print("File picked: ${file.name}");
      } else {
        print("No file selected");
      }
    } catch (e) {
      print("Error picking file: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      endDrawer: Drawer(
        width: 1500,
        child:
            _showPostsPage
                ? _buildPostsPage()
                : _showGalleryPage
                ? _buildGalleryPage()
                : _buildOriginalDrawerContent(),
      ),
      body: ListView(
        shrinkWrap: true,
        children: [
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
            height: 600,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.all(10),
                  child: Text(
                    "Teachers List",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                const Divider(),
                Expanded(
                  child: Scrollbar(
                    controller: _scrollController,
                    thickness: 8,
                    radius: const Radius.circular(10),
                    child: ListView.builder(
                      controller: _scrollController,
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
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (context) {
                                          return AlertDialog(
                                            backgroundColor: Colors.white,
                                            title: Text(
                                              'Write the Reason not Accept',
                                            ),
                                            content: TextFormField(
                                              decoration: InputDecoration(
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                hintText:
                                                    'Enter why doesn\'t accept the teacher',
                                              ),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () {
                                                  Navigator.pop(context);
                                                },
                                                child: Text(
                                                  'Cancel',
                                                  style: TextStyle(
                                                    color: Colors.red,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 20,
                                                  ),
                                                ),
                                              ),
                                              TextButton(
                                                onPressed: () {},
                                                child: Text(
                                                  'Accept',
                                                  style: TextStyle(
                                                    color: Colors.green,
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      );
                                    },
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

  Widget _buildOriginalDrawerContent() {
    return SingleChildScrollView(
      child: Column(
        spacing: 30,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Colors.blue),
            child: Center(
              child: Text(
                'Image Drawer',
                style: TextStyle(fontSize: 20, color: Colors.white),
              ),
            ),
          ),
          ...List.generate(teacherinfo.length, (index) {
            return Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                '${teacherinfo[index]} ',
                style: const TextStyle(fontSize: 20),
              ),
            );
          }),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Video Description', style: TextStyle(fontSize: 30)),
              Container(
                height: 200,
                margin: const EdgeInsets.all(10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: IconButton(
                  onPressed: _pickeFile,
                  icon: const Icon(Icons.add, size: 90),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.download, size: 40),
                  ),
                ],
              ),
            ],
          ),
          const Text('Description', style: TextStyle(fontSize: 30)),
          Container(
            margin: const EdgeInsets.all(10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              border: Border.all(width: 2, color: Colors.black),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'this will add the teacher description will understand everything',
              style: TextStyle(fontSize: 20),
            ),
          ),
          InkWell(
            onTap: () {
              setState(() {
                _showGalleryPage = true;
                _showPostsPage = false;
              });
            },
            child: Container(
              margin: const EdgeInsets.all(10),
              padding: const EdgeInsets.all(80),
              decoration: BoxDecoration(
                color: Colors.grey,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: const [
                  Text(
                    'Gallery',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 40, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
          InkWell(
            onTap: () {
              setState(() {
                _showPostsPage = true;
                _showGalleryPage = false;
              });
            },
            child: Container(
              margin: const EdgeInsets.all(10),
              padding: const EdgeInsets.all(80),
              decoration: BoxDecoration(
                color: Colors.grey,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: const [
                  Text(
                    'Posts',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 40, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(width: 2, color: Colors.grey),
            ),
            height: 300,
            child: ListView.builder(
              itemCount: 20,
              itemBuilder: (context, index) {
                return ListTile(
                  title: const Text('Earn money'),
                  subtitle: const Text('Date and Time'),
                  trailing: const Text('\$4.0', style: TextStyle(fontSize: 20)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGalleryPage() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          AppBar(
            automaticallyImplyLeading: false,
            title: const Text('Gallery'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                setState(() {
                  _showGalleryPage = false;
                });
              },
            ),
            bottom: const TabBar(
              tabs: [
                Tab(text: 'Images', icon: Icon(Icons.image)),
                Tab(text: 'Videos', icon: Icon(Icons.videocam)),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                // Images Tab Content
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                    itemCount: 12,
                    itemBuilder: (context, index) {
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.blue[100],
                          borderRadius: BorderRadius.circular(8),
                          image: const DecorationImage(
                            image: AssetImage('assets/images/spken_cafe.png'),
                            fit: BoxFit.cover,
                          ),
                        ),
                        child: Stack(
                          children: [
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                color: Colors.black54,
                                padding: const EdgeInsets.all(4),
                                child: Text(
                                  'Image ${index + 1}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // Videos Tab Content
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                    itemCount: 6,
                    itemBuilder: (context, index) {
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.red[100],
                          borderRadius: BorderRadius.circular(8),
                          image: const DecorationImage(
                            image: AssetImage('assets/images/spken_cafe.png'),
                            fit: BoxFit.cover,
                          ),
                        ),
                        child: Stack(
                          children: [
                            const Center(
                              child: Icon(
                                Icons.play_circle_filled,
                                color: Colors.white,
                                size: 40,
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                color: Colors.black54,
                                padding: const EdgeInsets.all(4),
                                child: Text(
                                  'Video ${index + 1}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostsPage() {
    return ListView(
      shrinkWrap: true,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new),
              onPressed: () {
                setState(() {
                  _showPostsPage = false;
                });
              },
            ),
            Spacer(),
            Text('Posts', style: TextStyle(fontSize: 20)),
            Spacer(),
          ],
        ),
        Teacher_Posts(),
      ],
    );
  }
}

List<String> teacherinfo = ['Name: ', 'Email: ', 'Phone Number: '];
