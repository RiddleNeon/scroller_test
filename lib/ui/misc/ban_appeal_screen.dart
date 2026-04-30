import 'package:flutter/material.dart';
import 'package:lumox/base_logic.dart';

import '../theme/theme_ui_values.dart';

class BanAppealScreen extends StatefulWidget {
  final String userId;
  final void Function()? onAppealSuccess;

  const BanAppealScreen({super.key, required this.userId, this.onAppealSuccess});

  @override
  State<BanAppealScreen> createState() => _BanAppealScreenState();
}

class _BanAppealScreenState extends State<BanAppealScreen> {
  final TextEditingController _appealController = TextEditingController();
  bool _isSubmitting = false;

  bool get _isValid => _appealController.text.trim().length >= 10;

  @override
  void initState() {
    super.initState();
    _appealController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _appealController.dispose();
    super.dispose();
  }

  Future<void> _submitAppeal() async {
    if (!_isValid || _isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      userRepository
          .appealBanSupabase(widget.userId, _appealController.text.trim())
          .then((_) {
            print("Ban appeal submitted successfully for user ${widget.userId}");
            widget.onAppealSuccess?.call();
          })
          .catchError((e) {
            if (!mounted) return;
            print("Error submitting ban appeal: $e");

            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Something went wrong. Please try again.")));
          })
          .whenComplete(() {
            if (mounted) {
              setState(() => _isSubmitting = false);
            }
          });

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Appeal submitted successfully.")));

      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;

      print("Error submitting ban appeal: $e");

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Something went wrong. Please try again.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Ban Appeal"), centerTitle: true),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.uiRadiusMd)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Submit an Appeal", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      const Text("If you believe your ban was a mistake, please explain your situation clearly. Our team will review your request."),
                      const SizedBox(height: 20),

                      TextField(
                        controller: _appealController,
                        maxLines: 6,
                        decoration: InputDecoration(
                          hintText: "Explain why your ban should be lifted...",
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(context.uiRadiusMd)),
                          errorText: _appealController.text.isEmpty || _isValid ? null : "Minimum 10 characters required",
                        ),
                      ),

                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isValid && !_isSubmitting ? _submitAppeal : null,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.uiRadiusMd)),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text("Submit Appeal"),
                        ),
                      ),
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
