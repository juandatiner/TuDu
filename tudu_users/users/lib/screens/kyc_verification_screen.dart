import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

import '../widgets/validacion_formulario.dart';
import '../widgets/camera_capture_mixin.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import '../services/user_api.dart';
import 'registration_screen.dart';
import 'welcome_screen.dart';

class KycVerificationScreen extends StatefulWidget {
  final String email;

  /// Motivo escrito por el admin cuando el KYC fue rechazado. Sin esto el
  /// aliado volvía al mismo formulario sin saber qué había fallado y reenviaba
  /// las mismas fotos.
  final String? motivoRechazo;

  const KycVerificationScreen({super.key, required this.email, this.motivoRechazo});

  @override
  State<KycVerificationScreen> createState() => _KycVerificationScreenState();
}

class _KycVerificationScreenState extends State<KycVerificationScreen>
    with TickerProviderStateMixin, CameraCaptureMixin {
  static const Color _brandColor = Color(0xFF78BF32);
  static const Color _bgColor = Color(0xFFF4F2F2);

  File? _cedulaFrente;
  File? _cedulaReverso;
  File? _selfie;

  // Qué documento falta: se marca la tarjeta en rojo en vez de decirlo abajo.
  bool _faltaFrente = false;
  bool _faltaReverso = false;
  bool _faltaSelfie = false;
  String? _avisoGeneral;

  bool _isUploading = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    detectarDispositivo();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _volver() {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => RegistrationScreen(email: widget.email),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  void _mostrarSoporte() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(context.tr('support_soon_title')),
        content: Text(context.tr('support_soon_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('accept')),
          ),
        ],
      ),
    );
  }

  bool get _canContinue =>
      _cedulaFrente != null && _cedulaReverso != null && _selfie != null;

  /// El aviso general solo tiene sentido mientras falte algún documento.
  void _revisarAviso() {
    if (!_faltaFrente && !_faltaReverso && !_faltaSelfie) _avisoGeneral = null;
  }

  Future<void> _continuar() async {
    if (!_canContinue) {
      // Se marcan los tres a la vez: así se ve de un vistazo cuáles faltan.
      setState(() {
        _faltaFrente = _cedulaFrente == null;
        _faltaReverso = _cedulaReverso == null;
        _faltaSelfie = _selfie == null;
        _avisoGeneral = context.tr('upload_marked_documents');
      });
      return;
    }

    setState(() => _avisoGeneral = null);

    setState(() => _isUploading = true);

    try {
      // Convertir imágenes a base64 para enviarlas al backend
      final cedulaFrenteB64 = base64Encode(await _cedulaFrente!.readAsBytes());
      final cedulaReversoB64 = base64Encode(await _cedulaReverso!.readAsBytes());
      final selfieB64 = base64Encode(await _selfie!.readAsBytes());

      await KycUsuarioApi.enviar(
        email: widget.email,
        cedulaFrente: cedulaFrenteB64,
        cedulaReverso: cedulaReversoB64,
        selfie: selfieB64,
      );

      if (!mounted) return;

      // Sea cual sea la respuesta del servidor, dejamos seguir al aliado
      // La verificación la revisará el admin más tarde
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => WelcomeScreen(email: widget.email),
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
    } catch (e) {
      // Si hay error de red, igual dejamos continuar (modo optimista)
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => WelcomeScreen(email: widget.email),
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 40,
        centerTitle: true,
        title: SizedBox(
          height: 26,
          child: FittedBox(
            fit: BoxFit.contain,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Tu',
                  style: const TextStyle(
                    fontFamily: 'TitanOne',
                    fontSize: 30,
                    color: _brandColor,
                    height: 0.85,
                  ),
                ),
                Text(
                  'Du',
                  style: const TextStyle(
                    fontFamily: 'TitanOne',
                    fontSize: 30,
                    color: _brandColor,
                    height: 0.85,
                  ),
                ),
              ],
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: _isUploading ? null : _volver,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.support_agent, color: Colors.black87),
            onPressed: _mostrarSoporte,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Solo el progreso queda fijo bajo la AppBar. Todo lo demás —
            // título, aviso de datos reales y tarjetas — scrollea.
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
              child: _buildProgressIndicator(step: 2),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
              // Rechazo anterior: va arriba de todo, antes del título, porque
              // es la razón por la que el aliado está viendo esta pantalla otra vez.
              if ((widget.motivoRechazo ?? '').isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.error_outline, size: 18, color: Colors.red),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(context.tr('kyc_rejected_title'),
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(widget.motivoRechazo!,
                          style: TextStyle(
                              fontSize: 13,
                              color: Colors.black.withOpacity(0.75),
                              height: 1.4)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              // Título
              Text(context.tr('identity_verification'),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                context.tr('kyc_intro'),
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black.withOpacity(0.55),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: Colors.orange.shade900, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        context.tr('kyc_disclaimer'),
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.orange.shade900,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Tarjeta cédula frente
              _buildDocumentCard(
                title: context.tr('id_front'),
                subtitle: context.tr('id_front_hint'),
                icon: Icons.credit_card,
                file: _cedulaFrente,
                falta: _faltaFrente,
                onTap: () => tomarFoto(
                  etiqueta: 'CEDULA FRENTE',
                  onListo: (f) {
                    _cedulaFrente = f;
                    _faltaFrente = false;
                    _revisarAviso();
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Tarjeta cédula reverso
              _buildDocumentCard(
                title: context.tr('id_back'),
                subtitle: context.tr('id_back_hint'),
                icon: Icons.credit_card_outlined,
                file: _cedulaReverso,
                falta: _faltaReverso,
                onTap: () => tomarFoto(
                  etiqueta: 'CEDULA REVERSO',
                  onListo: (f) {
                    _cedulaReverso = f;
                    _faltaReverso = false;
                    _revisarAviso();
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Selfie – solo cámara
              _buildSelfieCard(),
              const SizedBox(height: 12),

              // Aviso seguridad
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _brandColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _brandColor.withOpacity(0.25)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.shield_outlined, color: _brandColor, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        context.tr('documents_safe'),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black.withOpacity(0.65),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              Validacion.aviso(context, _avisoGeneral),

              // Botón continuar
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isUploading ? null : _continuar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brandColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                    disabledBackgroundColor: _brandColor.withOpacity(0.5),
                  ),
                  child: _isUploading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(context.tr('continue_button'),
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required File? file,
    required VoidCallback onTap,
    bool falta = false,
  }) {
    final hasFile = file != null;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: falta
                ? Validacion.colorError
                : hasFile
                    ? _brandColor
                    : Colors.black.withOpacity(0.15),
            width: (hasFile || falta) ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            if (hasFile)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                child: Image.file(
                  file,
                  height: 130,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              )
            else
              Container(
                height: 130,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F0F0),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, size: 44, color: Colors.black.withOpacity(0.2)),
                      const SizedBox(height: 8),
                      Text(
                        context.tr('tap_to_add'),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.black.withOpacity(0.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    hasFile ? Icons.check_circle : icon,
                    color: hasFile ? _brandColor : Colors.black.withOpacity(0.35),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        if (!hasFile)
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black.withOpacity(0.45),
                            ),
                          ),
                        if (hasFile)
                          Text(
                            context.tr('photo_added'),
                            style: TextStyle(
                              fontSize: 12,
                              color: _brandColor.withOpacity(0.8),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: Colors.black.withOpacity(0.3),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelfieCard() {
    final hasFile = _selfie != null;

    return GestureDetector(
      onTap: () => tomarFoto(
        etiqueta: 'SELFIE',
        camaraPreferida: CameraDevice.front,
        maxWidth: 800,
        onListo: (f) {
          _selfie = f;
          _faltaSelfie = false;
          _revisarAviso();
        },
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _faltaSelfie
                ? Validacion.colorError
                : hasFile
                    ? _brandColor
                    : Colors.black.withOpacity(0.15),
            width: (hasFile || _faltaSelfie) ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Previsualizador de selfie
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFF0F0F0),
                  border: Border.all(
                    color: hasFile ? _brandColor : Colors.black.withOpacity(0.15),
                    width: 2,
                  ),
                  image: hasFile
                      ? DecorationImage(
                          image: FileImage(_selfie!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: !hasFile
                    ? Center(
                        child: AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (_, __) => Transform.scale(
                            scale: _pulseAnimation.value,
                            child: Icon(
                              Icons.face_outlined,
                              size: 34,
                              color: Colors.black.withOpacity(0.2),
                            ),
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('selfie'),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasFile ? context.tr('selfie_taken') : context.tr('selfie_hint'),
                      style: TextStyle(
                        fontSize: 12,
                        color: hasFile
                            ? _brandColor.withOpacity(0.8)
                            : Colors.black.withOpacity(0.45),
                        height: 1.4,
                      ),
                    ),
                    if (!hasFile) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _brandColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock_outline, size: 12, color: _brandColor),
                            const SizedBox(width: 4),
                            Text(
                              context.tr('camera_only'),
                              style: TextStyle(
                                fontSize: 11,
                                color: _brandColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                hasFile ? Icons.check_circle : Icons.camera_alt_outlined,
                color: hasFile ? _brandColor : Colors.black.withOpacity(0.35),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressIndicator({required int step}) {
    return Column(
      children: [
        Row(
          children: List.generate(2, (i) {
            final activo = i + 1 <= step;
            return Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: activo
                            ? _brandColor
                            : Colors.black.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  if (i < 1) const SizedBox(width: 4),
                ],
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _stepLabel(context.tr('step_data'), step >= 1),
            _stepLabel(context.tr('step_verification'), step >= 2),
          ],
        ),
      ],
    );
  }

  Widget _stepLabel(String label, bool activo) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: activo ? FontWeight.w600 : FontWeight.normal,
        color: activo ? _brandColor : Colors.black.withOpacity(0.4),
      ),
    );
  }
}
