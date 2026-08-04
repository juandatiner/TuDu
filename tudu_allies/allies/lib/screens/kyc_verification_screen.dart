import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import '../services/ally_api.dart';
import 'service_setup_screen.dart';

class KycVerificationScreen extends StatefulWidget {
  final String email;

  const KycVerificationScreen({super.key, required this.email});

  @override
  State<KycVerificationScreen> createState() => _KycVerificationScreenState();
}

class _KycVerificationScreenState extends State<KycVerificationScreen>
    with TickerProviderStateMixin {
  static const Color _brandColor = Color(0xFF78BF32);
  static const Color _bgColor = Color(0xFFF4F2F2);

  File? _cedulaFrente;
  File? _cedulaReverso;
  File? _selfie;

  bool _isUploading = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
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

  Future<void> _pickImage({
    required bool fromCamera,
    required Function(File) onPicked,
  }) async {
    final picker = ImagePicker();
    final source = fromCamera ? ImageSource.camera : ImageSource.gallery;

    final XFile? picked = await picker.pickImage(
      source: source,
      imageQuality: 70,
      maxWidth: 1200,
    );

    if (picked != null) {
      setState(() => onPicked(File(picked.path)));
    }
  }

  Future<void> _takeSelfie() async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 70,
      maxWidth: 800,
    );
    if (picked != null) {
      setState(() => _selfie = File(picked.path));
    }
  }

  // Método eliminado - se usa directamente showModalBottomSheet en el build

  Widget _actionTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: const Color(0xFFF4F2F2),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: _brandColor),
              const SizedBox(width: 16),
              Text(
                label,
                style: const TextStyle(fontSize: 15, color: Colors.black87),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _canContinue =>
      _cedulaFrente != null && _cedulaReverso != null && _selfie != null;

  Future<void> _continuar() async {
    if (!_canContinue) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Por favor completa los tres documentos'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      // Convertir imágenes a base64 para enviarlas al backend
      final cedulaFrenteB64 = base64Encode(await _cedulaFrente!.readAsBytes());
      final cedulaReversoB64 = base64Encode(await _cedulaReverso!.readAsBytes());
      final selfieB64 = base64Encode(await _selfie!.readAsBytes());

      await AliadoApi.enviarKyc(
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
          pageBuilder: (_, __, ___) => ServiceSetupScreen(email: widget.email),
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
          pageBuilder: (_, __, ___) => ServiceSetupScreen(email: widget.email),
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),

              // Logo pequeño
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Tu',
                    style: const TextStyle(
                      fontFamily: 'TitanOne',
                      fontSize: 36,
                      color: _brandColor,
                      height: 0.85,
                    ),
                  ),
                  Text(
                    'Du',
                    style: const TextStyle(
                      fontFamily: 'TitanOne',
                      fontSize: 36,
                      color: _brandColor,
                      height: 0.85,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Progreso
              _buildProgressIndicator(step: 2),
              const SizedBox(height: 28),

              // Título
              const Text(
                'Verificación de identidad',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'Necesitamos confirmar que eres tú.\nTus documentos son revisados por nuestro equipo.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black.withOpacity(0.55),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Tarjeta cédula frente
              _buildDocumentCard(
                title: 'Cédula – Parte frontal',
                subtitle: 'Asegúrate de que sea legible',
                icon: Icons.credit_card,
                file: _cedulaFrente,
                onTap: () => showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.white,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  builder: (_) => _sourceSelector(
                    onCamera: () {
                      Navigator.pop(context);
                      _pickImage(
                        fromCamera: true,
                        onPicked: (f) => setState(() => _cedulaFrente = f),
                      );
                    },
                    onGallery: () {
                      Navigator.pop(context);
                      _pickImage(
                        fromCamera: false,
                        onPicked: (f) => setState(() => _cedulaFrente = f),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Tarjeta cédula reverso
              _buildDocumentCard(
                title: 'Cédula – Parte trasera',
                subtitle: 'Con todos los datos visibles',
                icon: Icons.credit_card_outlined,
                file: _cedulaReverso,
                onTap: () => showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.white,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  builder: (_) => _sourceSelector(
                    onCamera: () {
                      Navigator.pop(context);
                      _pickImage(
                        fromCamera: true,
                        onPicked: (f) => setState(() => _cedulaReverso = f),
                      );
                    },
                    onGallery: () {
                      Navigator.pop(context);
                      _pickImage(
                        fromCamera: false,
                        onPicked: (f) => setState(() => _cedulaReverso = f),
                      );
                    },
                  ),
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
                        'Tus documentos están cifrados y seguros. Solo nuestro equipo de verificación los revisa.',
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
              const SizedBox(height: 32),

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
                      : const Text(
                          'Continuar',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
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
            color: hasFile ? _brandColor : Colors.black.withOpacity(0.15),
            width: hasFile ? 2 : 1,
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
                        'Toca para agregar',
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
                            '¡Foto agregada! Toca para cambiarla',
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
      onTap: _takeSelfie,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasFile ? _brandColor : Colors.black.withOpacity(0.15),
            width: hasFile ? 2 : 1,
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
                      'Selfie de verificación',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasFile
                          ? '¡Selfie tomada! Toca para repetirla'
                          : 'Se tomará con tu cámara frontal.\nNo se puede adjuntar de galería.',
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
                              'Solo cámara',
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

  Widget _sourceSelector({
    required VoidCallback onCamera,
    required VoidCallback onGallery,
  }) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Agregar foto',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          _actionTile(icon: Icons.camera_alt_outlined, label: 'Usar cámara', onTap: onCamera),
          const SizedBox(height: 8),
          _actionTile(icon: Icons.photo_library_outlined, label: 'Elegir de galería', onTap: onGallery),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator({required int step}) {
    return Column(
      children: [
        Row(
          children: List.generate(3, (i) {
            final completed = i + 1 < step;
            final active = i + 1 == step;
            return Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: completed || active
                            ? _brandColor
                            : Colors.black.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  if (i < 2) const SizedBox(width: 4),
                ],
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _stepLabel('Datos', step >= 1),
            _stepLabel('Verificación', step >= 2),
            _stepLabel('Servicio', step >= 3),
          ],
        ),
      ],
    );
  }

  Widget _stepLabel(String label, bool active) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: active ? FontWeight.w600 : FontWeight.normal,
        color: active ? _brandColor : Colors.black.withOpacity(0.4),
      ),
    );
  }
}
