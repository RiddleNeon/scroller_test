import 'package:wurp/logic/quests/quest.dart';
import 'package:wurp/tools/supabase_tests/supabase_login_test.dart';

import '../../base_logic.dart';
QuestRepository questRepo = QuestRepository();
class QuestRepository {
  
  
  Map _questToMap(Quest quest, String updateMessage) => {
    'quest_id': quest.id,
    'created_by': currentUser.id,
    'title': quest.name,
    'description': quest.description,
    'difficulty': quest.difficulty,
    'update_message': updateMessage,
    'pos_x': quest.posX,
    'pos_y': quest.posY,
    'size_x': quest.sizeX,
    'size_y': quest.sizeY,
  };
  
  Future<void> addQuest(Quest quest) async {
    await supabaseClient.from('quests').insert({
      'id': quest.id,
      'created_by': currentUser.id,
    });

    updateQuest(quest, "initial version");
  }
  
  Future<void> updateQuest(Quest quest, String message) async {
    await supabaseClient.from('quest_versions').insert(_questToMap(quest, message)).select().single();
  }
  
  Future<void> deleteQuest(int questId) async {
    await supabaseClient.from('quest_connections').insert({
      'created_at': DateTime.now().toUtc(),
      'created_by': currentUser.id,
      'from_id': questId,
      'to_id': questId,
      'type': 'prerequisite',
      'is_deleted': true,
      'update_message': 'quest deleted',
    }).select().single();
    
    await supabaseClient.from('quest_versions').insert({
      'created_at': DateTime.now().toUtc(),
      'created_by': currentUser.id,
      'quest_id': questId,
      'title': '',
      'description': '',
      'difficulty': 0,
      'update_message': 'quest deleted',
      'pos_x': 0,
      'pos_y': 0,
      'size_x': 0,
      'size_y': 0,
      'is_deleted': true,
    }).select().single();
  }
}