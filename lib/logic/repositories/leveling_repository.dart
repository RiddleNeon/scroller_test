
import 'package:wurp/base_logic.dart';
import 'package:wurp/tools/supabase_tests/supabase_login_test.dart';

class LevelingRepository {
  
  Future<double> getLevelProgress(String subject) async {
    final response = await supabaseClient.from('profile_levels').select('level').eq('category', subject).eq('user_id', currentUser.id).single();
    return (response['level'] as num).toDouble();
  }
  
  
  
  
}