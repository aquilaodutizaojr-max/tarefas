import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(const MinimaListApp());

const Color _kCorBase = Color(0xFF00BFA5);

// ─────────────────────────────────────────────────────────────
// APP + TEMAS (claro e escuro automáticos, seguindo o celular)
// ─────────────────────────────────────────────────────────────
class MinimaListApp extends StatelessWidget {
  const MinimaListApp({super.key});

  ThemeData _tema(Brightness brilho) {
    final esquema = ColorScheme.fromSeed(
      seedColor: _kCorBase,
      brightness: brilho,
    );
    final claro = brilho == Brightness.light;

    return ThemeData(
      useMaterial3: true,
      colorScheme: esquema,
      scaffoldBackgroundColor:
      claro ? const Color(0xFFF0F7F5) : const Color(0xFF0F1514),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '2Do MinimaList',
      theme: _tema(Brightness.light),
      darkTheme: _tema(Brightness.dark),
      themeMode: ThemeMode.system,
      home: const TelaTarefas(),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// MODELOS (POO)
// ─────────────────────────────────────────────────────────────
enum Prioridade {
  baixa('Baixa', Color(0xFF2E9E6B)),
  media('Média', Color(0xFFEF8A00)),
  alta('Alta', Color(0xFFE53935));

  const Prioridade(this.rotulo, this.cor);

  final String rotulo;
  final Color cor;
}

enum Filtro { todas, pendentes, concluidas }

class Tarefa {
  Tarefa({
    required this.id,
    required this.titulo,
    this.concluida = false,
    this.prioridade = Prioridade.media,
  });

  final String id;
  String titulo;
  bool concluida;
  Prioridade prioridade;
}

// Dados devolvidos pelo painel de criar/editar
class _Rascunho {
  const _Rascunho(this.titulo, this.prioridade);

  final String titulo;
  final Prioridade prioridade;
}

String _dataHoje() {
  const dias = [
    'Segunda-feira',
    'Terça-feira',
    'Quarta-feira',
    'Quinta-feira',
    'Sexta-feira',
    'Sábado',
    'Domingo',
  ];
  const meses = [
    'janeiro',
    'fevereiro',
    'março',
    'abril',
    'maio',
    'junho',
    'julho',
    'agosto',
    'setembro',
    'outubro',
    'novembro',
    'dezembro',
  ];
  final agora = DateTime.now();
  return '${dias[agora.weekday - 1]}, ${agora.day} de ${meses[agora.month - 1]}';
}

// ─────────────────────────────────────────────────────────────
// TELA PRINCIPAL
// ─────────────────────────────────────────────────────────────
class TelaTarefas extends StatefulWidget {
  const TelaTarefas({super.key});

  @override
  State<TelaTarefas> createState() => _TelaTarefasState();
}

class _TelaTarefasState extends State<TelaTarefas> {
  final List<Tarefa> _tarefas = [
    Tarefa(id: '1', titulo: 'Comprar pão, leite e ovo'),
    Tarefa(
      id: '2',
      titulo: 'Responder e-mails do trabalho',
      concluida: true,
      prioridade: Prioridade.alta,
    ),
    Tarefa(id: '3', titulo: 'Academia às 18h', prioridade: Prioridade.baixa),
  ];

  Filtro _filtro = Filtro.todas;

  int get _concluidas => _tarefas.where((t) => t.concluida).length;
  int get _pendentes => _tarefas.length - _concluidas;

  // Pendentes primeiro, concluídas no fim
  List<Tarefa> get _visiveis {
    final pendentes = _tarefas.where((t) => !t.concluida);
    final concluidas = _tarefas.where((t) => t.concluida);

    if (_filtro == Filtro.pendentes) return pendentes.toList();
    if (_filtro == Filtro.concluidas) return concluidas.toList();
    return [...pendentes, ...concluidas];
  }

  // Abre o painel para criar (tarefa == null) ou editar uma tarefa
  Future<void> _abrirEditor([Tarefa? tarefa]) async {
    final resultado = await showModalBottomSheet<_Rascunho>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _PainelTarefa(tarefa: tarefa),
    );

    if (resultado == null || !mounted) return;

    setState(() {
      if (tarefa == null) {
        _tarefas.insert(
          0,
          Tarefa(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            titulo: resultado.titulo,
            prioridade: resultado.prioridade,
          ),
        );
      } else {
        tarefa.titulo = resultado.titulo;
        tarefa.prioridade = resultado.prioridade;
      }
    });
  }

  void _alternar(Tarefa tarefa) {
    HapticFeedback.selectionClick();
    setState(() => tarefa.concluida = !tarefa.concluida);
  }

  void _remover(Tarefa tarefa) {
    final indice = _tarefas.indexOf(tarefa);
    if (indice < 0) return;

    setState(() => _tarefas.removeAt(indice));

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text('"${tarefa.titulo}" removida'),
          action: SnackBarAction(
            label: 'Desfazer',
            onPressed: () {
              setState(() {
                _tarefas.insert(math.min(indice, _tarefas.length), tarefa);
              });
            },
          ),
        ),
      );
  }

  void _concluirTodas() {
    if (_pendentes == 0) return;
    setState(() {
      for (final t in _tarefas) {
        t.concluida = true;
      }
    });
  }

  Future<void> _limparConcluidas() async {
    final quantidade = _concluidas;
    if (quantidade == 0) return;

    final confirmou = await showDialog<bool>(
      context: context,
      builder: (contextoDialogo) => AlertDialog(
        title: const Text('Limpar concluídas?'),
        content: Text(
          quantidade == 1
              ? '1 tarefa concluída será removida.'
              : '$quantidade tarefas concluídas serão removidas.',
          style: TextStyle(
            color: Theme.of(contextoDialogo).colorScheme.onSurface,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(contextoDialogo, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(contextoDialogo, true),
            child: const Text('Limpar'),
          ),
        ],
      ),
    );

    if (confirmou == true && mounted) {
      setState(() => _tarefas.removeWhere((t) => t.concluida));
    }
  }

  @override
  Widget build(BuildContext context) {
    final visiveis = _visiveis;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirEditor(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nova tarefa'),
      ),
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Column(
          children: [
            _Cabecalho(
              total: _tarefas.length,
              concluidas: _concluidas,
              onConcluirTodas: _concluirTodas,
              onLimpar: _limparConcluidas,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<Filtro>(
                  showSelectedIcon: false,
                  segments: [
                    const ButtonSegment(
                      value: Filtro.todas,
                      label: Text('Todas'),
                    ),
                    ButtonSegment(
                      value: Filtro.pendentes,
                      label: Text('Pendentes'),
                    ),
                    ButtonSegment(
                      value: Filtro.concluidas,
                      label: Text('Concluídas'),
                    ),
                  ],
                  selected: {_filtro},
                  onSelectionChanged: (selecao) =>
                      setState(() => _filtro = selecao.first),
                ),
              ),
            ),
            Expanded(
              child: visiveis.isEmpty
                  ? _Vazio(filtro: _filtro)
                  : ListView.builder(
                padding: const EdgeInsets.only(top: 4, bottom: 100),
                itemCount: visiveis.length,
                // Ajuda o Flutter a reaproveitar os itens (mais rápido)
                findChildIndexCallback: (chave) {
                  if (chave is! ValueKey<String>) return null;
                  final i =
                  visiveis.indexWhere((t) => t.id == chave.value);
                  return i < 0 ? null : i;
                },
                itemBuilder: (context, index) {
                  final tarefa = visiveis[index];
                  return _ItemTarefa(
                    key: ValueKey<String>(tarefa.id),
                    tarefa: tarefa,
                    onAlternar: () => _alternar(tarefa),
                    onEditar: () => _abrirEditor(tarefa),
                    onRemover: () => _remover(tarefa),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// CABEÇALHO COM PROGRESSO
// ─────────────────────────────────────────────────────────────
class _Cabecalho extends StatelessWidget {
  const _Cabecalho({
    required this.total,
    required this.concluidas,
    required this.onConcluirTodas,
    required this.onLimpar,
  });

  final int total;
  final int concluidas;
  final VoidCallback onConcluirTodas;
  final VoidCallback onLimpar;

  @override
  Widget build(BuildContext context) {
    final escuro = Theme.of(context).brightness == Brightness.dark;
    final topo = MediaQuery.of(context).padding.top;
    final progresso = total == 0 ? 0.0 : concluidas / total;
    final tudoFeito = total > 0 && concluidas == total;

    final String resumo;
    if (total == 0) {
      resumo = 'Nenhuma tarefa ainda';
    } else if (tudoFeito) {
      resumo = 'Tudo feito! 🎉';
    } else {
      resumo = '$concluidas de $total concluídas';
    }

    return Container(
      padding: EdgeInsets.fromLTRB(24, topo + 12, 8, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: escuro
              ? const [Color(0xFF00695C), Color(0xFF004D40)]
              : const [Color(0xFF00BFA5), Color(0xFF00897B)],
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '2Do MinimaList',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _dataHoje(),
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
                tooltip: 'Mais opções',
                onSelected: (valor) {
                  if (valor == 'todas') {
                    onConcluirTodas();
                  } else {
                    onLimpar();
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'todas', child: Text('Concluir todas')),
                  PopupMenuItem(
                    value: 'limpar',
                    child: Text('Limpar concluídas'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        resumo,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      '${(progresso * 100).round()}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: progresso),
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOutCubic,
                    builder: (context, valor, _) => LinearProgressIndicator(
                      value: valor,
                      minHeight: 8,
                      backgroundColor: Colors.white.withAlpha(60),
                      valueColor:
                      const AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// ITEM DA LISTA
// ─────────────────────────────────────────────────────────────
class _ItemTarefa extends StatelessWidget {
  const _ItemTarefa({
    super.key,
    required this.tarefa,
    required this.onAlternar,
    required this.onEditar,
    required this.onRemover,
  });

  final Tarefa tarefa;
  final VoidCallback onAlternar;
  final VoidCallback onEditar;
  final VoidCallback onRemover;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final prioridade = tarefa.prioridade;

    // Entrada suave quando o item aparece
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      builder: (context, valor, filho) => Opacity(
        opacity: valor,
        child: Transform.translate(
          offset: Offset(0, 16 * (1 - valor)),
          child: filho,
        ),
      ),
      child: Dismissible(
        key: ValueKey<String>('dismiss-${tarefa.id}'),
        direction: DismissDirection.endToStart,
        onDismissed: (_) => onRemover(),
        background: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          padding: const EdgeInsets.only(right: 24),
          alignment: Alignment.centerRight,
          decoration: BoxDecoration(
            color: esquema.error,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(Icons.delete_rounded, color: esquema.onError),
        ),
        child: Card(
          elevation: tarefa.concluida ? 0 : 1.5,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ListTile(
            onTap: onAlternar,
            contentPadding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
            leading: _Marcador(feito: tarefa.concluida),
            title: Text(
              tarefa.titulo,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: esquema.onSurface,
                decoration: tarefa.concluida
                    ? TextDecoration.lineThrough
                    : TextDecoration.none,
                decorationColor: esquema.primary,
                decorationThickness: 2,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Icon(Icons.flag_rounded, size: 14, color: prioridade.cor),
                  const SizedBox(width: 4),
                  Text(
                    prioridade.rotulo,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: prioridade.cor,
                    ),
                  ),
                ],
              ),
            ),
            trailing: IconButton(
              tooltip: 'Editar',
              icon: Icon(Icons.edit_rounded, color: esquema.primary),
              onPressed: onEditar,
            ),
          ),
        ),
      ),
    );
  }
}

// Círculo que preenche quando a tarefa é concluída
class _Marcador extends StatelessWidget {
  const _Marcador({required this.feito});

  final bool feito;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: feito ? esquema.primary : Colors.transparent,
        border: Border.all(color: esquema.primary, width: 2),
      ),
      child: feito
          ? Icon(Icons.check_rounded, size: 18, color: esquema.onPrimary)
          : null,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// ESTADO VAZIO
// ─────────────────────────────────────────────────────────────
class _Vazio extends StatelessWidget {
  const _Vazio({required this.filtro});

  final Filtro filtro;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;

    final IconData icone;
    final String titulo;

    if (filtro == Filtro.concluidas) {
      icone = Icons.task_alt_rounded;
      titulo = 'Nada concluído ainda';
    } else if (filtro == Filtro.pendentes) {
      icone = Icons.celebration_rounded;
      titulo = 'Sem pendências';
    } else {
      icone = Icons.checklist_rounded;
      titulo = 'Sua lista está vazia';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: esquema.primary.withAlpha(30),
              ),
              child: Icon(icone, size: 44, color: esquema.primary),
            ),
            const SizedBox(height: 20),
            Text(
              titulo,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: esquema.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// PAINEL DE CRIAR / EDITAR (tem o próprio controller e o descarta)
// ─────────────────────────────────────────────────────────────
class _PainelTarefa extends StatefulWidget {
  const _PainelTarefa({this.tarefa});

  final Tarefa? tarefa;

  @override
  State<_PainelTarefa> createState() => _PainelTarefaState();
}

class _PainelTarefaState extends State<_PainelTarefa> {
  late final TextEditingController _controller =
  TextEditingController(text: widget.tarefa?.titulo);
  late Prioridade _prioridade = widget.tarefa?.prioridade ?? Prioridade.media;
  String? _erro;

  bool get _editando => widget.tarefa != null;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _salvar() {
    final texto = _controller.text.trim();
    if (texto.isEmpty) {
      setState(() => _erro = 'Digite o nome da tarefa');
      return;
    }
    Navigator.pop(context, _Rascunho(texto, _prioridade));
  }

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24,
        4,
        24,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _editando ? 'Editar tarefa' : 'Nova tarefa',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: esquema.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLength: 80,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            style: TextStyle(color: esquema.onSurface),
            onChanged: (_) {
              if (_erro != null) setState(() => _erro = null);
            },
            onSubmitted: (_) => _salvar(),
            decoration: InputDecoration(
              hintText: 'O que precisa ser feito?',
              hintStyle: TextStyle(color: esquema.primary),
              errorText: _erro,
              counterText: '',
              prefixIcon: Icon(Icons.edit_note_rounded, color: esquema.primary),
              filled: true,
              fillColor: esquema.primary.withAlpha(20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: esquema.primary, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Prioridade',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: esquema.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final p in Prioridade.values)
                ChoiceChip(
                  label: Text(
                    p.rotulo,
                    style: TextStyle(color: esquema.onSurface),
                  ),
                  avatar: Icon(Icons.flag_rounded, size: 18, color: p.cor),
                  selected: _prioridade == p,
                  selectedColor: p.cor.withAlpha(45),
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _prioridade = p),
                ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _salvar,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              _editando ? 'Salvar alterações' : 'Adicionar tarefa',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}