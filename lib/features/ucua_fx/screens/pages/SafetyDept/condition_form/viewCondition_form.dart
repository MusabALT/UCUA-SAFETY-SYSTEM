// ignore_for_file: prefer_const_constructors
import 'dart:io';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ucua_staging/features/ucua_fx/screens/widgets/form_container_widget.dart';
import 'package:ucua_staging/global_common/toast.dart';

class safeDeptViewUCForm extends StatefulWidget {
  final String docId;

  const safeDeptViewUCForm({Key? key, required this.docId}) : super(key: key);

  @override
  State<safeDeptViewUCForm> createState() => _safeDeptViewUCFormState();
}

class _safeDeptViewUCFormState extends State<safeDeptViewUCForm> {

  final TextEditingController _remarkController = TextEditingController();

  Map<String, dynamic>? formData;
  List<String> conditionImages = [];
  List<Map<String, dynamic>> followUps = [];
  List<String> _imageUrls = [];
  List<File?> _conditionImages = [null, null];
  /*List<File?> _conditionImages = [null, null];
  List<String> _conditionTakenImageUrls = [];*/

  String _status = 'Pending';
  String? approvalName;
  String? approvalDesignation;

  @override
  void initState() {
    super.initState();
    fetchFormData();
  }

  @override
  void dispose() {
    _remarkController.dispose();
    super.dispose();
  }

  Future<void> fetchFormData() async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance.collection('ucform').doc(widget.docId).get();
      if (doc.exists) {
        setState(() {
          formData = doc.data() as Map<String, dynamic>;
        });
        if (formData!['imageUrls'] != null) {
          _imageUrls = List<String>.from(formData!['imageUrls'] ?? []);
        }
        if (formData!['status'] == null) {
          await FirebaseFirestore.instance.collection('ucform').doc(widget.docId).update({'status': 'Pending'});
          setState(() {
            _status = 'Pending';
          });
        } else {
          setState(() {
            _status = formData!['status'];
          });
        }
        fetchFollowUps();
      }
    } catch (e) {
      print('Error fetching form data: $e');
    }
  }

  Future<void> fetchImages(List<dynamic> urls) async {
    List<String> fetchedUrls = [];
    for (String url in urls) {
      try {
        String downloadUrl = await FirebaseStorage.instance.ref(url).getDownloadURL();
        fetchedUrls.add(downloadUrl);
      } catch (e) {
        print('Error fetching image: $e');
      }
    }
    setState(() {
      conditionImages = fetchedUrls;
    });
  }

  Future<void> fetchFollowUps() async {
    try {
      QuerySnapshot query = await FirebaseFirestore.instance
          .collection('ucform')
          .doc(widget.docId)
          .collection('ucfollowup')
          .get();
      setState(() {
        followUps = query.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
      });
    } catch (e) {
      print('Error fetching follow-up data: $e');
    }
  }

  Future<void> _handleAction(String action) async {
    try {
      String currentUserId = FirebaseAuth.instance.currentUser!.uid;

      DocumentSnapshot userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .get();

      String userName = userSnapshot['firstName'] ?? 'Unknown User';
      String userRole = userSnapshot['role'] ?? 'Unknown Role';

      List<String> uploadedImageUrls = [];

      for (var file in _conditionImages) {
        if (file != null) {
          String fileName = 'followup_${DateTime.now().millisecondsSinceEpoch}.jpg';
          Reference ref = FirebaseStorage.instance.ref().child(fileName);
          UploadTask uploadTask = ref.putFile(file);
          TaskSnapshot snapshot = await uploadTask;
          String downloadUrl = await snapshot.ref.getDownloadURL();
          uploadedImageUrls.add(downloadUrl);
        }
      }

      Map<String, dynamic> followUpData = {
        'remark': _remarkController.text,
        'status': action,
        'imageUrls': uploadedImageUrls,
        'timestamp': Timestamp.now(),
        'userName': userName, 
        'userRole': userRole,
      };

      await FirebaseFirestore.instance
          .collection('ucform')
          .doc(widget.docId)
          .collection('ucfollowup')
          .add(followUpData);

      await FirebaseFirestore.instance.collection('ucform').doc(widget.docId).update({
        'status': action == 'Approve' ? 'Approved' : action == 'Reject' ? 'Rejected' : 'Pending',
        'approvalName': userName,
        'approvalDesignation': userRole,
      });

      setState(() {
        _status = action == 'Approve' ? 'Approved' : action == 'Reject' ? 'Rejected' : 'Pending';
        approvalName = userName;
        approvalDesignation = userRole;
      });

      showToast(message: "The form is $action");
      fetchFormData();
      fetchFollowUps();

      setState(() {
        followUps.add(followUpData);
        _remarkController.clear();
        _conditionImages = [null, null];
      });
    } catch (e) {
      print('Error saving follow-up: $e');
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Approved':
        return Colors.green;
      case 'Rejected':
        return Colors.red;
      case 'Pending':
      default:
        return Color.fromARGB(255, 216, 195, 7);
    }
  }

  Future<void> getImageGallery(int index, List<File?> imageList) async {
    final picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    setState(() {
      if (pickedFile != null) {
        imageList[index] = File(pickedFile.path);
      } else {
        print("No Image Picked!");
      }
    });
  }

  Widget _buildFollowUpUpdate() {
    followUps.sort((a, b) {
      Timestamp timestampA = a['timestamp'];
      Timestamp timestampB = b['timestamp'];
      return timestampB.compareTo(timestampA);
    });

    return Container(
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.5),
            spreadRadius: 2,
            blurRadius: 5,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Follow-Up Update',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue),
          ),
          SizedBox(height: 10),
          ...followUps.map((update) {
            return Container(
              padding: EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.security, color: Color.fromARGB(255, 33, 82, 243)),
                      SizedBox(width: 8),
                      Text(
                        update['userRole'] ?? 'Unknown Role', // Display the role
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Spacer(),
                      Text(
                        (update['timestamp'] as Timestamp).toDate().toString(),
                        style: TextStyle(color: const Color.fromARGB(255, 107, 107, 107), fontSize: 12),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(update['remark']),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      if (update['imageUrls'] != null && update['imageUrls'].length > 0)
                        ...update['imageUrls'].map<Widget>((url) {
                          return Expanded(
                            child: Image.network(
                              url,
                              height: 200,
                              fit: BoxFit.cover,
                            ),
                          );
                        }).toList(),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Unsafe Condition Form'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ),
        body: Container(
          color: Colors.grey.withOpacity(.35),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.5),
                      spreadRadius: 5,
                      blurRadius: 7,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Text(
                          '1. U-SEE, U-ACT',
                          style: TextStyle(fontSize: 24.0, fontWeight: FontWeight.bold, color: const Color.fromARGB(255, 151, 46, 170)),
                        ),
                      ),
                      const SizedBox(height: 20.0),
                      const Text(
                        'Location:',
                        style: TextStyle(fontSize: 16.0),
                      ),
                      const SizedBox(height: 4),
                      FormContainerWidget(
                        hintText: formData != null ? formData!['location'] : '',
                      ),
                      const SizedBox(height: 20.0),
                      const Text(
                        'Condition Details:',
                        style: TextStyle(fontSize: 16.0),
                      ),
                      const SizedBox(height: 4),
                      FormContainerWidget(
                        hintText: formData != null ? formData!['conditionDetails'] : '',
                      ),
                      const SizedBox(height: 20.0),
                      const Text(
                        'Action Pictures:',
                        style: TextStyle(fontSize: 16.0),
                      ),
                      const SizedBox(height: 4),
                      _imageUrls.isNotEmpty
                          ? CarouselSlider(
                              options: CarouselOptions(
                                height: 200.0,
                                enlargeCenterPage: true,
                                enableInfiniteScroll: false,
                                viewportFraction: 0.8,
                              ),
                              items: _imageUrls.sublist(0, _imageUrls.length < 3 ? _imageUrls.length : 2).map((url) {
                                return Container(
                                  margin: EdgeInsets.symmetric(horizontal: 5.0),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.all(Radius.circular(10.0)),
                                    child: Image.network(url, fit: BoxFit.cover, width: 1000.0),
                                  ),
                                );
                              }).toList(),
                            )
                          : Text('No images available'),
                      const SizedBox(height: 20.0),
                      const Text(
                        'Date:',
                        style: TextStyle(fontSize: 16.0),
                      ),
                      FormContainerWidget(
                        hintText: formData != null ? formData!['date'] : '',
                      ),
                      const SizedBox(height: 30.0),
                      Center(
                        child: Text(
                          '2. FOLLOW-UP & STATUS',
                          style: TextStyle(fontSize: 24.0, fontWeight: FontWeight.bold, color: const Color.fromARGB(255, 151, 46, 170)),
                        ),
                      ),
                      const SizedBox(height: 20.0),
                      const Text('REPORTER INFORMATION', style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4.0),
                      Text('\t\tNAME         : ${formData != null ? formData!['reporterName'] : ''}'),
                      Text('\t\tDESIGNATION  : ${formData != null ? formData!['reporterDesignation'] : ''}'),
                      Text('\t\tDATE         : ${formData != null ? formData!['date'] : ''}'),
                      const SizedBox(height: 20.0),
                      const Text(
                        'CHECKED BY (SAFETY DEPARTMENT OFFICER)',
                        style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 4.0),
                      if (_status != 'Pending') ...{
                        Text('\t\tNAME         : ${approvalName ?? ''}'),
                        Text('\t\tDESIGNATION  : ${approvalDesignation ?? ''}'),
                        Text('\t\tDATE         : ${DateTime.now().toString().substring(0, 10)}'),
                      },
                      const SizedBox(height: 20.0),
                      Row(
                        children: [
                          Text('\t\tSTATUS       : '),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getStatusColor(_status),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _status,
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20.0),
                      const Text(
                        'Remark:',
                        style: TextStyle(fontSize: 16.0),
                      ),
                      const SizedBox(height: 4),
                      TextFormField(
                        controller: _remarkController,
                        maxLines: null,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'Remark',
                        ),
                      ),
                      const SizedBox(height: 20.0),
                      const Text(
                        'Upload Action Taken Picture:',
                        style: TextStyle(fontSize: 16.0),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => getImageGallery(0, _conditionImages),
                            child: Container(
                              width: 150, // Adjusted width here
                              height: 150,
                              margin: EdgeInsets.only(right: 8.0),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: _conditionImages[0] != null
                                  ? Image.file(_conditionImages[0]!, fit: BoxFit.cover)
                                  : Center(
                                      child: Icon(Icons.add_a_photo, color: Colors.grey[800], size: 50),
                                    ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => getImageGallery(1, _conditionImages),
                            child: Container(
                              width: 150, // Adjusted width here
                              height: 150,
                              margin: EdgeInsets.only(left: 8.0), 
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: _conditionImages[1] != null
                                  ? Image.file(_conditionImages[1]!, fit: BoxFit.cover)
                                  : Center(
                                      child: Icon(Icons.add_a_photo, color: Colors.grey[800], size: 50),
                                    ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          ElevatedButton(
                            onPressed: () => _handleAction('Save'),
                            child: const Text('Save'),
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Color.fromRGBO(255, 255, 255, 1), 
                              backgroundColor: Color.fromARGB(255, 63, 63, 62),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () => _handleAction('Approve'),
                            child: const Text('Approve'),
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.white, 
                              backgroundColor: Colors.green,
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () => _handleAction('Reject'),
                            child: const Text('Reject'),
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.white, 
                              backgroundColor: Colors.red,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 30.0),
                      _buildFollowUpUpdate(), 
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}