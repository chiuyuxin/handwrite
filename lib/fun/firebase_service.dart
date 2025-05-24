import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  FirebaseFirestore firestore = FirebaseFirestore.instance;

  // 更新指定用戶資料
  Future<void> updateUserData(String userId) async {
    DocumentReference userRef = firestore.collection('users').doc(userId);

    try {
      await userRef.update({
        'saved_characters': ['char1', 'char2'],  // 新增 saved_characters 欄位
        'full_name': 'John Doe',  // 新增 full_name 欄位
      });
      print('用户资料更新成功');
    } catch (error) {
      print('更新失败: $error');
    }
  }

  // 更新所有用户资料结构
  Future<void> updateAllUsersDataStructure() async {
    // 获取所有用户文档
    QuerySnapshot querySnapshot = await firestore.collection('users').get();

    // 创建一个批次操作
    WriteBatch batch = firestore.batch();

    // 遍历所有文档，并为每个用户更新数据结构
    for (var doc in querySnapshot.docs) {
      DocumentReference docRef = doc.reference;

      // 更新数据结构：例如新增 saved_characters 字段，重命名字段等
      batch.update(docRef, {
        'saved_characters': [],  // 添加空的 'saved_characters' 字段
        'full_name': doc['name'],  // 假设原来有 'name' 字段
        'created_at': FieldValue.serverTimestamp(),  // 添加时间戳字段
      });
    }

    // 提交批次操作
    try {
      await batch.commit();
      print('所有用户的资料结构更新成功');
    } catch (error) {
      print('更新失败: $error');
    }
  }
}
