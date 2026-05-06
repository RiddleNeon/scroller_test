import 'package:lumox/base_logic.dart';
import 'package:lumox/tools/supabase_tests/supabase_login_test.dart';

class QuestTitleAliasRepository {
  static final QuestTitleAliasRepository instance = QuestTitleAliasRepository._();

  QuestTitleAliasRepository._();

  Future<List<String>> fetchAliases({required int questId}) async {
    final rows = await supabaseClient
        .from('quest_title_aliases')
        .select('alias')
        .eq('quest_id', questId);
    return (rows as List<dynamic>)
        .map<String>((row) => (row['alias'] as String? ?? '').trim())
        .where((alias) => alias.isNotEmpty)
        .toList();
  }

  Future<void> addAlias({required int questId, required String alias}) async {
    final trimmed = alias.trim();
    if (trimmed.isEmpty) return;

    await supabaseClient.from('quest_title_aliases').upsert({
      'quest_id': questId,
      'alias': trimmed,
      'created_by': currentAuthUserId(),
    });
  }

  Future<void> removeAlias({required int questId, required String alias}) async {
    final trimmed = alias.trim();
    if (trimmed.isEmpty) return;

    await supabaseClient
        .from('quest_title_aliases')
        .delete()
        .eq('quest_id', questId)
        .eq('alias', trimmed);
  }
}

final questTitleAliasRepository = QuestTitleAliasRepository.instance;

