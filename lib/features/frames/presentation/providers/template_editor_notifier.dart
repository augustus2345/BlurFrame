import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../data/models/frame_template.dart';
import '../../data/repositories/frame_repository.dart';

/// 模板编辑器在某一时刻的全部状态（M2-T4）。
///
/// 每一层都有 `enabled` 开关 + 一个非空 layer 实例：
/// - **enabled = true** → 该层会被写入最终保存的 [FrameTemplate]
/// - **enabled = false** → 该层在保存时被过滤掉（但实例仍保留，方便用户
///   切回时恢复原值）
///
/// 设计要点：
/// - **id == null** → 新建模式；保存时用 uuid 生成新 id
/// - **id != null** → 编辑现有模板；保存时保留 id + createdAt
/// - **isBuiltIn** 永远不能从编辑器被改（菜单已屏蔽；save() 里再防御一次）
class TemplateEditorState {
  TemplateEditorState({
    required this.id,
    required this.name,
    required this.isBuiltIn,
    required this.createdAt,
    required this.blurBorderEnabled,
    required this.blurBorder,
    required this.textWatermarkEnabled,
    required this.textWatermark,
    required this.colorStripeEnabled,
    required this.colorStripe,
  });

  /// null = 新建；非 null = 编辑现有。
  final String? id;

  /// 模板名（用户在顶部 TextField 编辑）。
  final String name;

  /// 内置模板恒为 true；编辑器不允许改（菜单 + save() 双重防御）。
  final bool isBuiltIn;

  /// 创建时间（编辑现有模板时才有；新建时为 null → 走 `FrameTemplate` 默认值）。
  final DateTime? createdAt;

  // 模糊边框
  final bool blurBorderEnabled;
  final BlurBorderLayer blurBorder;

  // 文字水印
  final bool textWatermarkEnabled;
  final TextWatermarkLayer textWatermark;

  // 颜色条
  final bool colorStripeEnabled;
  final ColorStripeLayer colorStripe;

  /// 全空（新建）初始状态：3 层都关闭，name 默认 "未命名模板"。
  ///
  /// 每层都用合理默认填充（即便 disabled），让用户打开后立刻有可调整的值。
  factory TemplateEditorState.empty() {
    return TemplateEditorState(
      id: null,
      name: '未命名模板',
      isBuiltIn: false,
      createdAt: null,
      blurBorderEnabled: false,
      blurBorder: BlurBorderLayer(intensity: 4, edge: true),
      textWatermarkEnabled: false,
      textWatermark: TextWatermarkLayer(
        text: 'Photo Beauty',
        position: WatermarkPosition.bottomCenter,
        fontSize: 14,
        color: 0xFFFFFFFF,
      ),
      colorStripeEnabled: false,
      colorStripe: ColorStripeLayer(
        color: 0xFF000000,
        width: 0.08,
        cornerRadius: 0,
        position: StripePosition.bottom,
      ),
    );
  }

  /// 从已有模板构造编辑器状态：每种 layer 类型最多保留第一个。
  ///
  /// 如果模板里某种 layer 完全没出现，对应 `enabled = false`，但 layer
  /// 实例仍是合理默认（让用户重新打开那一层时不用从零填）。
  factory TemplateEditorState.fromTemplate(FrameTemplate template) {
    BlurBorderLayer? blur;
    TextWatermarkLayer? wm;
    ColorStripeLayer? stripe;
    for (final layer in template.layers) {
      if (blur == null && layer is BlurBorderLayer) blur = layer;
      if (wm == null && layer is TextWatermarkLayer) wm = layer;
      if (stripe == null && layer is ColorStripeLayer) stripe = layer;
    }
    return TemplateEditorState(
      id: template.id,
      name: template.name,
      isBuiltIn: template.isBuiltIn,
      createdAt: template.createdAt,
      blurBorderEnabled: blur != null,
      blurBorder: blur ?? BlurBorderLayer(intensity: 4, edge: true),
      textWatermarkEnabled: wm != null,
      textWatermark: wm ??
          TextWatermarkLayer(
            text: 'Photo Beauty',
            position: WatermarkPosition.bottomCenter,
            fontSize: 14,
            color: 0xFFFFFFFF,
          ),
      colorStripeEnabled: stripe != null,
      colorStripe: stripe ??
          ColorStripeLayer(
            color: 0xFF000000,
            width: 0.08,
            cornerRadius: 0,
            position: StripePosition.bottom,
          ),
    );
  }

  /// 构造最终 [FrameTemplate]，[enabled = false] 的层被过滤掉。
  ///
  /// [finalId] 由调用方决定：
  /// - 新建：notifier 生成 uuid 后传入
  /// - 编辑：传入原 [id]
  FrameTemplate toTemplate({required String finalId}) {
    final layers = <FrameLayer>[];
    if (blurBorderEnabled) layers.add(blurBorder);
    if (textWatermarkEnabled) layers.add(textWatermark);
    if (colorStripeEnabled) layers.add(colorStripe);
    return FrameTemplate(
      id: finalId,
      name: name,
      layers: layers,
      isBuiltIn: isBuiltIn,
      createdAt: createdAt,
    );
  }

  /// 不可变更新；只暴露业务需要变更的字段。
  TemplateEditorState copyWith({
    String? name,
    bool? blurBorderEnabled,
    BlurBorderLayer? blurBorder,
    bool? textWatermarkEnabled,
    TextWatermarkLayer? textWatermark,
    bool? colorStripeEnabled,
    ColorStripeLayer? colorStripe,
  }) {
    return TemplateEditorState(
      id: id,
      name: name ?? this.name,
      isBuiltIn: isBuiltIn,
      createdAt: createdAt,
      blurBorderEnabled: blurBorderEnabled ?? this.blurBorderEnabled,
      blurBorder: blurBorder ?? this.blurBorder,
      textWatermarkEnabled: textWatermarkEnabled ?? this.textWatermarkEnabled,
      textWatermark: textWatermark ?? this.textWatermark,
      colorStripeEnabled: colorStripeEnabled ?? this.colorStripeEnabled,
      colorStripe: colorStripe ?? this.colorStripe,
    );
  }
}

/// 模板编辑器的状态机（Riverpod [AsyncNotifier]）。
///
/// - [build] 同步返回 [TemplateEditorState.empty]（让 UI 首帧不是 loading）
/// - [load] 异步加载现有模板；找不到抛 [StateError]（UI 转为错误态）
/// - 所有 set* 方法都是同步的，立刻更新 state（编辑器需要零延迟反馈）
/// - [save] 调 `repo.save(toTemplate())`；返回保存后的 [FrameTemplate]
///
/// 设计选择：[AsyncNotifier] 而不是 [Notifier] —— 加载模板是异步的（要
/// 读 Hive），错误态要显式展示（id 找不到 / 解析失败），用 [AsyncValue]
/// 走 4 态分派最自然。
class TemplateEditorNotifier extends AsyncNotifier<TemplateEditorState> {
  static const _uuid = Uuid();

  @override
  Future<TemplateEditorState> build() async {
    return TemplateEditorState.empty();
  }

  /// 加载现有模板（编辑模式）；[id] == null 时重置为空（新建模式）。
  ///
  /// 找不到 / 读取失败 → 抛 [StateError]（UI 走 [AsyncValue.error] 分支）。
  Future<void> load(String? id) async {
    if (id == null) {
      state = AsyncData(TemplateEditorState.empty());
      return;
    }
    state = const AsyncValue<TemplateEditorState>.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(frameRepositoryProvider);
      final template = repo.getById(id);
      if (template == null) {
        throw StateError('Template "$id" not found');
      }
      return TemplateEditorState.fromTemplate(template);
    });
  }

  /// 修改模板名。
  void setName(String name) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(name: name));
  }

  // ── 模糊边框 ─────────────────────────────────────────────

  void setBlurBorderEnabled(bool enabled) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(blurBorderEnabled: enabled));
  }

  void setBlurIntensity(double intensity) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        blurBorder: BlurBorderLayer(
          intensity: intensity,
          edge: current.blurBorder.edge,
        ),
      ),
    );
  }

  void setBlurEdgeOnly(bool edge) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        blurBorder: BlurBorderLayer(
          intensity: current.blurBorder.intensity,
          edge: edge,
        ),
      ),
    );
  }

  // ── 文字水印 ─────────────────────────────────────────────

  void setTextWatermarkEnabled(bool enabled) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(textWatermarkEnabled: enabled));
  }

  void setWatermarkText(String text) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        textWatermark: TextWatermarkLayer(
          text: text,
          position: current.textWatermark.position,
          fontSize: current.textWatermark.fontSize,
          color: current.textWatermark.color,
        ),
      ),
    );
  }

  void setWatermarkPosition(WatermarkPosition position) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        textWatermark: TextWatermarkLayer(
          text: current.textWatermark.text,
          position: position,
          fontSize: current.textWatermark.fontSize,
          color: current.textWatermark.color,
        ),
      ),
    );
  }

  void setWatermarkFontSize(double fontSize) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        textWatermark: TextWatermarkLayer(
          text: current.textWatermark.text,
          position: current.textWatermark.position,
          fontSize: fontSize,
          color: current.textWatermark.color,
        ),
      ),
    );
  }

  void setWatermarkColor(int color) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        textWatermark: TextWatermarkLayer(
          text: current.textWatermark.text,
          position: current.textWatermark.position,
          fontSize: current.textWatermark.fontSize,
          color: color,
        ),
      ),
    );
  }

  // ── 颜色条 ───────────────────────────────────────────────

  void setColorStripeEnabled(bool enabled) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(colorStripeEnabled: enabled));
  }

  void setStripeColor(int color) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        colorStripe: ColorStripeLayer(
          color: color,
          width: current.colorStripe.width,
          cornerRadius: current.colorStripe.cornerRadius,
          position: current.colorStripe.position,
        ),
      ),
    );
  }

  void setStripeWidth(double width) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        colorStripe: ColorStripeLayer(
          color: current.colorStripe.color,
          width: width,
          cornerRadius: current.colorStripe.cornerRadius,
          position: current.colorStripe.position,
        ),
      ),
    );
  }

  void setStripeCornerRadius(double radius) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        colorStripe: ColorStripeLayer(
          color: current.colorStripe.color,
          width: current.colorStripe.width,
          cornerRadius: radius,
          position: current.colorStripe.position,
        ),
      ),
    );
  }

  void setStripePosition(StripePosition position) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        colorStripe: ColorStripeLayer(
          color: current.colorStripe.color,
          width: current.colorStripe.width,
          cornerRadius: current.colorStripe.cornerRadius,
          position: position,
        ),
      ),
    );
  }

  /// 把当前 state 持久化到 Hive，返回保存后的 [FrameTemplate]。
  ///
  /// - 新建（[TemplateEditorState.id] == null）→ 生成 uuid 作为新 id
  /// - 编辑 → 保留原 id + createdAt
  /// - 内置模板（[TemplateEditorState.isBuiltIn]） → 抛 [BuiltInTemplateException]
  /// - 其他错误 → 上抛
  Future<FrameTemplate> save() async {
    final current = state.value;
    if (current == null) {
      throw StateError('Editor state not initialized');
    }
    if (current.isBuiltIn) {
      throw BuiltInTemplateException(current.id ?? '<new>');
    }
    final finalId = current.id ?? _uuid.v4();
    final template = current.toTemplate(finalId: finalId);
    await ref.read(frameRepositoryProvider).save(template);
    return template;
  }
}

/// 编辑器状态入口。
final templateEditorProvider =
    AsyncNotifierProvider<TemplateEditorNotifier, TemplateEditorState>(
  TemplateEditorNotifier.new,
);
