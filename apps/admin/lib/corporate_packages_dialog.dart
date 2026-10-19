import 'package:flutter/material.dart';
import 'package:mazeduneh_admin/corporate_api.dart';
import 'package:mazeduneh_admin/formatters.dart';

class CorporatePackagesDialog extends StatefulWidget {
  const CorporatePackagesDialog({super.key, required this.api});

  final CorporateApiClient api;

  @override
  State<CorporatePackagesDialog> createState() => _CorporatePackagesDialogState();
}

class _CorporatePackagesDialogState extends State<CorporatePackagesDialog> {
  final code = TextEditingController();
  final name = TextEditingController();
  final description = TextEditingController();
  final itemName = TextEditingController();
  final quantity = TextEditingController(text: '1');
  final unit = TextEditingController(text: 'عدد');
  final unitPrice = TextEditingController();
  List<CorporatePackage> packages = [];
  List<CorporatePackageItem> items = [];
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
    name.dispose();
    description.dispose();
    itemName.dispose();
    quantity.dispose();
    unit.dispose();
    unitPrice.dispose();
    super.dispose();
  }

  Future<void> refresh() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await widget.api.fetchPackages();
      if (mounted) {
        setState(() {
          packages = result;
          loading = false;
        });
      }
    } catch (exception) {
      if (mounted) setState(() {
        error = exception;
        loading = false;
      });
    }
  }

  void selectPackage(String? value) {
    setState(() {
      selectedCode = value;
      CorporatePackage? selected;
      for (final item in packages) {
        if (item.code == value) {
          selected = item;
          break;
        }
      }
      code.text = selected?.code ?? '';
      name.text = selected?.name ?? '';
      description.text = selected?.description ?? '';
      isActive = selected?.isActive ?? true;
      items = selected?.items.toList() ?? [];
    });
  }

  void addItem() {
    final parsedQuantity = parsePersianNumber(quantity.text);
    final parsedPrice = parseTomanToRial(unitPrice.text);
    if (itemName.text.trim().isEmpty || unit.text.trim().isEmpty ||
        parsedQuantity == null || parsedQuantity <= 0 ||
        parsedPrice == null || parsedPrice < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('نام، واحد، تعداد و قیمت قلم را بررسی کنید.')),
      );
      return;
    }
    setState(() {
      items = [
        ...items,
        CorporatePackageItem(
          name: itemName.text.trim(),
          quantity: parsedQuantity,
          unit: unit.text.trim(),
          unitPrice: parsedPrice,
        ),
      ];
      itemName.clear();
      quantity.text = '1';
      unit.text = 'عدد';
      unitPrice.clear();
    });
  }

  Future<void> save() async {
    if (code.text.trim().isEmpty || name.text.trim().isEmpty || items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('کد، نام بسته و دست‌کم یک قلم لازم است.')),
      );
      return;
    }
    setState(() => saving = true);
    try {
      final saved = await widget.api.savePackage(
        code: code.text.trim().toLowerCase(),
        name: name.text.trim(),
        description: description.text.trim(),
        isActive: isActive,
        items: items,
      );
      if (!mounted) return;
      setState(() {
        packages = [
          ...packages.where((item) => item.code != saved.code),
          saved,
        ]..sort((a, b) => a.name.compareTo(b.name));
        selectedCode = saved.code;
        code.text = saved.code;
        items = saved.items;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('بسته ذخیره شد؛ درخواست‌های قبلی بدون تغییر می‌مانند.')),
      );
    } catch (exception) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(exception.toString())),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('مدیریت بسته‌های فروش سازمانی'),
        content: SizedBox(
          width: 720,
          height: MediaQuery.sizeOf(context).height * .72,
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : error != null
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('بارگذاری بسته‌ها انجام نشد: $error'),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: refresh,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('تلاش دوباره'),
                        ),
                      ],
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final narrow = constraints.maxWidth < 520;
                        return ListView(
                          padding: EdgeInsets.zero,
                          children: [
                            DropdownButtonFormField<String?>(
                              value: selectedCode,
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: 'انتخاب برای ویرایش'),
                              items: [
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('بستهٔ جدید'),
                                ),
                                ...packages.map((item) => DropdownMenuItem<String?>(
                                      value: item.code,
                                      child: Text(
                                        '${item.name}${item.isActive ? '' : ' · غیرفعال'}',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    )),
                              ],
                              onChanged: selectPackage,
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: code,
                              readOnly: selectedCode != null,
                              decoration: const InputDecoration(
                                labelText: 'کد پایدار بسته',
                                hintText: 'standard-gift',
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(controller: name, decoration: const InputDecoration(labelText: 'نام نمایشی')),
                            const SizedBox(height: 10),
                            TextField(
                              controller: description,
                              maxLines: 2,
                              decoration: const InputDecoration(labelText: 'توضیحات کوتاه'),
                            ),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              value: isActive,
                              title: const Text('نمایش در فرم فروشگاه'),
                              onChanged: (value) => setState(() => isActive = value),
                            ),
                            const Divider(),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text('اقلام بسته · قیمت‌ها به تومان'),
                            ),
                            const SizedBox(height: 6),
                            if (items.isEmpty)
                              const ListTile(title: Text('برای ساخت بسته، قلم اضافه کنید.'))
                            else
                              ...items.asMap().entries.map((entry) {
                                final index = entry.key;
                                final item = entry.value;
                                return ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(item.name),
                                  subtitle: Text(
                                    '${formatPersianNumber(item.quantity)} ${item.unit} · ${formatToman(item.unitPrice)} تومان',
                                  ),
                                  trailing: IconButton(
                                    tooltip: 'حذف قلم',
                                    onPressed: () => setState(() {
                                      final updated = [...items];
                                      updated.removeAt(index);
                                      items = updated;
                                    }),
                                    icon: const Icon(Icons.delete_outline_rounded),
                                  ),
                                );
                              }),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                SizedBox(
                                  width: narrow ? constraints.maxWidth : constraints.maxWidth * .44,
                                  child: TextField(
                                    controller: itemName,
                                    decoration: const InputDecoration(labelText: 'نام قلم'),
                                  ),
                                ),
                                SizedBox(
                                  width: narrow ? 100 : constraints.maxWidth * .16,
                                  child: TextField(
                                    controller: quantity,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    inputFormatters: const [PersianDigitsInputFormatter()],
                                    decoration: const InputDecoration(labelText: 'تعداد'),
                                  ),
                                ),
                                SizedBox(
                                  width: narrow ? 100 : constraints.maxWidth * .16,
                                  child: TextField(
                                    controller: unit,
                                    decoration: const InputDecoration(labelText: 'واحد'),
                                  ),
                                ),
                                SizedBox(
                                  width: narrow ? 140 : constraints.maxWidth * .18,
                                  child: TextField(
                                    controller: unitPrice,
                                    inputFormatters: const [PersianGroupedIntegerInputFormatter()],
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: const InputDecoration(labelText: 'قیمت هر واحد (تومان)'),
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: addItem,
                                  icon: const Icon(Icons.add_rounded),
                                  label: const Text('افزودن قلم'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                'جمع هر بسته: ${formatToman(items.fold<num>(0, (sum, item) => sum + item.quantity * item.unitPrice))} تومان',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('بستن')),
          if (!loading && error == null)
            FilledButton.icon(
              onPressed: saving ? null : save,
              icon: saving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save_rounded),
              label: const Text('ذخیره بسته'),
            ),
        ],
      );
}

