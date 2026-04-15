

import 'dart:convert';

import 'package:wurp/logic/tasks/task.dart';

import '../../base_logic.dart';
import '../../tools/supabase_tests/supabase_login_test.dart';

class TaskRepository {
  
  ///returns if the solution is correct
  Future<bool> solveTask(int taskId, Map<String, dynamic> solution) async {
    final response = await supabaseClient.rpc('solve_task', params: {'p_task_id': taskId, 'p_answer_data': jsonEncode(solution)}).single();
    return response as bool? ?? false;
  }
  
  Future<void> createTask(Task task) async {
    if(task.createdBy != currentUser.id) {
      throw Exception("Cannot create task with createdBy different from current user");
    }
    
    await supabaseClient.from('tasks').insert(task.toJson());
  }  
  
  Future<void> addSolutionToTask(int taskId, Map<String, dynamic> solution) async {
    await supabaseClient.from('task_solutions').insert({
      'task_id': taskId,
      'data': jsonEncode(solution),
      'created_by': currentUser.id,
    });
  }
  
  
}