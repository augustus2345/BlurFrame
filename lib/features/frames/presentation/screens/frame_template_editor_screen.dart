import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/empty_state.dart';
import '../../data/models/frame_template.dart';
import '../../data/repositories/frame_repository.dart';
import '../providers/frame_template_list_provider.dart';
import '../providers/template_editor_notifier.dart';
import '../widgets/editor_subwidgets/blur_border_editor.dart';
import '../widgets/editor_subwidgets/color_stripe_editor.dart';
import '../widgets/editor_subwidgets/text_watermark_editor.dart';
import '../widgets/frame_preview_painter.dart';
import '../widgets/layer_switch_group.dart';

/// 模版编辑器 `/frames/editor`（M2-T4）。
///
/// **入口模式**：
/// - 无 [templateId] → 新建空白模板（3 层默认全关）
/// - `?templateId=foo` → 编辑现有模板
///
/// **3 个工作区**（自上而下）：
/// 1. 顶部预览（[FramePreview]，实时反映编辑状态）
/// 2. 模版名 TextField
/// 3. 3 个 [LayerSwitchGroup]（模糊边框 / 文字水印 / 颜色条）
/// + 底部固定"保存模板"按钮
///
/// **4 态显式**（与 M1-T5 / M2-T3 一致）：
/// - **loading** — [load] 切换到 AsyncLoading
/// - **error** — 模板 id 找不到 / 读取失败
/// - **empty** — 不适用（首屏是空 state；这里直接渲染编辑器）
/// - **success** — 编辑器主界面
///
/// **数据流**：UI watch [templateEditorProvider]；用户操作 → notifier
/// 同步更新 state → UI rebuild（包含预览）。
class FrameTemplateEditorScreen extends ConsumerStatefulWidget {
  const FrameTemplateEditorScreen({
    this.templateId,
    super.key,
  });

  /// 编辑现有模板时传入；null = 新建。
  final String? templateId;

  @override
  ConsumerState<FrameTemplateEditorScreen> createState() =>
      _FrameTemplateEditorScreenState();
}

class _FrameTemplateEditorScreenState
    extends ConsumerState<FrameTemplateEditorScreen> {
  @override
  void initState() {
    super.initState();
    // load 涉及 IO（Hive 读），必须 post-frame；用 mounted 守卫防 race。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(templateEditorProvider.notifier).load(widget.templateId);
    });
  }

  Future<void> _onSavePressed() async {
    final notifier = ref.read(templateEditorProvider.notifier);
    final state = ref.read(templateEditorProvider).value;
    if (state == null) return;

    if (state.isBuiltIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('内置模板不可修改')),
      );
      return;
    }
    if (state.name.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入模板名')),
      );
      return;
    }

    try {
      final saved = await notifier.save();
      if (!mounted) return;
      // 让列表页 refresh
      await ref.read(frameTemplateListProvider.notifier).refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: const Key('frame_template_editor_saved_snackbar'),
          content: Text('已保存「${saved.name}」'),
          duration: const Duration(seconds: 2),
        ),
      );
      // canPop 防御：测试时直接 pumpWidget home=editor 的话没有上层页面
      if (context.canPop()) context.pop();
    } on BuiltInTemplateException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('内置模板不可修改')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(templateEditorProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.templateId == null ? '新建模板' : '编辑模板',
        ),
      ),
      body: asyncState.when(
        loading: () => const Center(
          child: CircularProgressIndicator(
            key: Key('frame_template_editor_loading_indicator'),
          ),
        ),
        error: (error, _) => _LoadErrorState(
          error: error,
          onRetry: () => ref
              .read(templateEditorProvider.notifier)
              .load(widget.templateId),
        ),
        data: (state) => _EditorBody(state: state),
      ),
      bottomNavigationBar: asyncState.value == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton(
                  key: const Key('frame_template_editor_save_button'),
                  onPressed:
                      asyncState.value!.isBuiltIn ? null : _onSavePressed,
                  child: const Text('保存模板'),
                ),
              ),
            ),
    );
  }
}

/// 加载错误态：模板 id 找不到 / Hive 读失败。
class _LoadErrorState extends StatelessWidget {
  const _LoadErrorState({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      key: const Key('frame_template_editor_load_error'),
      icon: Icons.error_outline,
      title: '加载模板失败',
      message: '$error',
      action: FilledButton(
        key: const Key('frame_template_editor_load_retry_button'),
        onPressed: onRetry,
        child: const Text('重试'),
      ),
    );
  }
}

/// 编辑器主内容：预览 + 名称 + 3 个层分组。
class _EditorBody extends ConsumerStatefulWidget {
  const _EditorBody({required this.state});

  final TemplateEditorState state;

  @override
  ConsumerState<_EditorBody> createState() => _EditorBodyState();
}

class _EditorBodyState extends ConsumerState<_EditorBody> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.state.name);
  }

  @override
  void didUpdateWidget(_EditorBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    // state.name 变化时同步 controller（避免用户切到外部修改后 UI 失同步）
    if (widget.state.name != _nameController.text) {
      _nameController.text = widget.state.name;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// 用 state 构造预览用的 [FrameTemplate]（enabled 的层才会进 layers 列表）。
  FrameTemplate _previewTemplate() {
    final state = widget.state;
    return FrameTemplate(
      id: state.id ?? 'preview',
      name: state.name,
      layers: <FrameLayer>[
        if (state.blurBorderEnabled) state.blurBorder,
        if (state.textWatermarkEnabled) state.textWatermark,
        if (state.colorStripeEnabled) state.colorStripe,
      ],
      isBuiltIn: state.isBuiltIn,
      createdAt: state.createdAt,
    );
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(templateEditorProvider.notifier);
    final state = widget.state;
    return ListView(
      key: const Key('frame_template_editor_body'),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
      children: [
        // 预览
        Center(
          child: SizedBox(
            width: 200,
            height: 200,
            child: FramePreview(template: _previewTemplate()),
          ),
        ),
        const SizedBox(height: 16),
        // 模版名
        TextField(
          key: const Key('frame_template_editor_name_field'),
          controller: _nameController,
          onChanged: notifier.setName,
          decoration: const InputDecoration(
            labelText: '模板名',
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        // 模糊边框
        LayerSwitchGroup(
          keyPrefix: 'blur',
          title: '模糊边框',
          enabled: state.blurBorderEnabled,
          onEnabledChanged: notifier.setBlurBorderEnabled,
          paramsBuilder: (_) => BlurBorderEditor(
            layer: state.blurBorder,
            onIntensityChanged: notifier.setBlurIntensity,
            onEdgeOnlyChanged: notifier.setBlurEdgeOnly,
          ),
        ),
        // 文字水印
        LayerSwitchGroup(
          keyPrefix: 'watermark',
          title: '文字水印',
          enabled: state.textWatermarkEnabled,
          onEnabledChanged: notifier.setTextWatermarkEnabled,
          paramsBuilder: (_) => TextWatermarkEditor(
            layer: state.textWatermark,
            onTextChanged: notifier.setWatermarkText,
            onPositionChanged: notifier.setWatermarkPosition,
            onFontSizeChanged: notifier.setWatermarkFontSize,
            onColorChanged: notifier.setWatermarkColor,
          ),
        ),
        // 颜色条
        LayerSwitchGroup(
          keyPrefix: 'stripe',
          title: '颜色条',
          enabled: state.colorStripeEnabled,
          onEnabledChanged: notifier.setColorStripeEnabled,
          paramsBuilder: (_) => ColorStripeEditor(
            layer: state.colorStripe,
            onColorChanged: notifier.setStripeColor,
            onWidthChanged: notifier.setStripeWidth,
            onCornerRadiusChanged: notifier.setStripeCornerRadius,
            onPositionChanged: notifier.setStripePosition,
          ),
        ),
      ],
    );
  }
}
