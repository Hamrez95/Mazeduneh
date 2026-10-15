import 'package:flutter/material.dart';
import 'package:mazeduneh_admin/corporate_api.dart';

class CorporateResponseTemplatesDialog extends StatefulWidget {
  const CorporateResponseTemplatesDialog({super.key, required this.api});

  final CorporateApiClient api;

  @override
  State<CorporateResponseTemplatesDialog> createState() =>
      _CorporateResponseTemplatesDialogState();
}

class _CorporateResponseTemplatesDialogState
    extends State<CorporateResponseTemplatesDialog> {
  final code = TextEditingController();
  final title = TextEditingController();
  final body = TextEditingController();
  List<CorporateResponseTemplate> templates = [];
  String? selectedCode;
  bool isActive = true;
  bool loading = true;
  bool saving = false;
  Object? error;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  @override
  void dispose() {
    code.dispose();
    title.dispose();
    body.dispose();
    super.dispose();
  }

  Future<void> refresh() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await widget.api.fetchResponseTemplates();
      if (mounted) {
        setState(() {
          templates = result;
          loading = false;
        });
      }
    } catch (exception) {
      if (mounted) {
        setState(() {
          error = exception;
          loading = false;
        });
      }
    }
  }

  void selectTemplate(String? value) {
    setState(() {
      selectedCode = value;
      CorporateResponseTemplate? selected;
      for (final template in templates) {
        if (template.code == value) {
          selected = template;
          break;
        }
      }
      code.text = selected?.code ?? '';
      title.text = selected?.title ?? '';
      body.text = selected?.body ?? '';
      isActive = selected?.isActive ?? true;
    });
  }

  Future<void> save() async {
    if (code.text.trim().isEmpty || title.text.trim().isEmpty ||
        body.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('کد، عنوان و متن پاسخ الزامی است.')),
      );
      return;
    }
    setState(() => saving = true);
    try {
      final saved = await widget.api.saveResponseTemplate(
        code: code.text.trim().toLowerCase(),
        title: title.text.trim(),
        body: body.text.trim(),
        isActive: isActive,
      );
      if (!mounted) return;
      setState(() {
        templates = [
          ...templates.where((item) => item.code != saved.code),
          saved,
        ]..sort((a, b) => a.title.compareTo(b.title));
        selectedCode = saved.code;
        code.text = saved.code;
        title.text = saved.title;
        body.text = saved.body;
        isActive = saved.isActive;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('پاسخ آماده ذخیره شد.')),
      );
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(exception.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('مدیریت پاسخ‌های آماده'),
        content: SizedBox(
          width: 660,
          height: MediaQuery.sizeOf(context).height * .72,
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : error != null
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('بارگذاری پاسخ‌ها انجام نشد: $error'),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: refresh,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('تلاش دوباره'),
                        ),
                      ],
                    )
                  : ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        DropdownButtonFormField<String?>(
                          value: selectedCode,
                          isExpanded: true,
                          decoration:
                              const InputDecoration(labelText: 'انتخاب برای ویرایش'),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('پاسخ جدید'),
                            ),
                            ...templates.map(
                              (item) => DropdownMenuItem<String?>(
                                value: item.code,
                                child: Text(
                                  '${item.title}${item.isActive ? '' : ' · غیرفعال'}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                          onChanged: selectTemplate,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: code,
                          readOnly: selectedCode != null,
                          decoration: const InputDecoration(
                            labelText: 'کد پایدار پاسخ',
                            hintText: 'welcome-company',
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: title,
                          maxLength: 120,
                          decoration: const InputDecoration(labelText: 'عنوان'),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: body,
                          minLines: 5,
                          maxLines: 9,
                          maxLength: 2000,
                          decoration: const InputDecoration(
                            labelText: 'متن پاسخ',
                            alignLabelWithHint: true,
                          ),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: isActive,
                          title: const Text('قابل انتخاب در جزئیات درخواست'),
                          onChanged: (value) => setState(() => isActive = value),
                        ),
                        const Text(
                          'پاسخ انتخاب‌شده در جزئیات قابل ویرایش است و ثبت آن فقط تاریخچه را به‌روزرسانی می‌کند.',
                          style: TextStyle(color: Colors.black54, fontSize: 12),
                        ),
                      ],
                    ),
        ),
        actions: [
          TextButton(
            onPressed: saving ? null : () => Navigator.of(context).pop(),
            child: const Text('بستن'),
          ),
          FilledButton.icon(
            onPressed: loading || error != null || saving ? null : save,
            icon: saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_rounded),
            label: const Text('ذخیره'),
          ),
        ],
      );
}
