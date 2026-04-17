
import 'package:wurp/logic/tasks/task.dart';

import '../../base_logic.dart';
import '../../tools/supabase_tests/supabase_login_test.dart';

TaskRepository taskRepository = TaskRepository();

class TaskRepository {
  
  /// Full RPC response from solve_task_v2.
  Future<Map<String, dynamic>> solveTaskDetailed(
    int taskId,
    Map<String, dynamic> solution, {
    int? versionId,
  }) async {
    final response = await supabaseClient
        .rpc('solve_task_v2', params: {
          'p_task_id': taskId,
          'p_answer_data': solution,
          'p_version_id': versionId,
        })
        .single();

    return Map<String, dynamic>.from(response as Map);
  }

  ///returns if the solution is correct
  Future<bool> solveTask(int taskId, Map<String, dynamic> solution) async {
    final result = await solveTaskDetailed(taskId, solution);
    return result['is_correct'] as bool? ?? false;
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
      'data': solution,
      'created_by': currentUser.id,
    });
  }

  Future<Map<String, dynamic>> createTaskDraftVersion({
    required int taskId,
    required String title,
    required Map<String, dynamic> ui,
    required Map<String, dynamic> logic,
  }) async {
    final response = await supabaseClient
        .rpc('create_task_draft_version', params: {
          'p_task_id': taskId,
          'p_title': title,
          'p_ui': ui,
          'p_logic': logic,
        })
        .single();

    return Map<String, dynamic>.from(response as Map);
  }

  Future<Map<String, dynamic>> cloneTaskVersion({
    required int taskId,
    required int sourceVersionId,
    String? newTitle,
  }) async {
    final response = await supabaseClient
        .rpc('clone_task_version', params: {
          'p_task_id': taskId,
          'p_source_version_id': sourceVersionId,
          'p_new_title': newTitle,
        })
        .single();

    return Map<String, dynamic>.from(response as Map);
  }

  Future<Map<String, dynamic>> publishTaskVersion({
    required int taskId,
    required int versionId,
    bool makeCurrent = true,
  }) async {
    final response = await supabaseClient
        .rpc('publish_task_version', params: {
          'p_task_id': taskId,
          'p_version_id': versionId,
          'p_make_current': makeCurrent,
        })
        .single();

    return Map<String, dynamic>.from(response as Map);
  }

  Future<List<Map<String, dynamic>>> fetchTaskVersions(int taskId) async {
    final response = await supabaseClient
        .from('task_versions')
        .select()
        .eq('task_id', taskId)
        .order('version_no', ascending: false);

    return (response as List<dynamic>)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  Future<List<Map<String, dynamic>>> fetchMyTasks() async {
    final response = await supabaseClient
        .from('tasks')
        .select('id, created_at, title, type, subjects, xp_reward, xp_punishment, current_version_id')
        .eq('created_by', currentUser.id)
        .order('created_at', ascending: false);

    return (response as List<dynamic>)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  Future<Map<String, dynamic>> createTaskShell({
    required String type,
    required String title,
    required List<String> subjects,
    required double xpReward,
    required double xpPunishment,
    Map<String, dynamic> data = const <String, dynamic>{},
  }) async {
    final response = await supabaseClient
        .from('tasks')
        .insert({
          'type': type,
          'title': title,
          'subjects': subjects,
          'xp_reward': xpReward,
          'xp_punishment': xpPunishment,
          'data': data,
          'created_by': currentUser.id,
        })
        .select()
        .single();

    return Map<String, dynamic>.from(response as Map);
  }

  Future<Map<String, dynamic>> updateTaskDraftVersion({
    required int versionId,
    required String title,
    required Map<String, dynamic> ui,
    required Map<String, dynamic> logic,
  }) async {
    final response = await supabaseClient
        .from('task_versions')
        .update({
          'title': title,
          'ui': ui,
          'logic': logic,
        })
        .eq('id', versionId)
        .eq('created_by', currentUser.id)
        .eq('status', 'draft')
        .select()
        .single();

    return Map<String, dynamic>.from(response as Map);
  }

  Future<Map<String, dynamic>> fetchTaskUiSchemaV1() async {
    final response = await supabaseClient.rpc('get_task_ui_schema_v1').single();
    return Map<String, dynamic>.from(response as Map);
  }
}