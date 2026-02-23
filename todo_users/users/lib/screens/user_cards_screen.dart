import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../providers/theme_provider.dart';
import '../config.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui';

class MyCardsScreen extends StatefulWidget {
  final String userEmail;

  const MyCardsScreen({super.key, required this.userEmail});

  @override
  State<MyCardsScreen> createState() => _MyCardsScreenState();
}

class _MyCardsScreenState extends State<MyCardsScreen>
    with SingleTickerProviderStateMixin {
  List<CreditCard> _creditCards = [];
  bool _isLoading = true;
  bool _isSaving = false;

  // Controlador para la animación de la tarjeta
  late AnimationController _controller;
  late Animation<double> _frontRotation;
  late Animation<double> _backRotation;

  @override
  void initState() {
    super.initState();
    _loadCreditCards();
  }

  Future<void> _loadCreditCards() async {
    try {
      // Aquí se cargarían las tarjetas del usuario desde el backend
      final response = await http.get(
        Uri.parse('${Config.baseUrl}/users/cards/${widget.userEmail}'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _creditCards = data
              .map<CreditCard>((card) => CreditCard(
                    id: card['id'].toString(),
                    cardNumber: card['card_number'],
                    cardHolder: card['card_holder'],
                    expiryDate: card['expiry_date'],
                    cvv: card['cvv'],
                    isDefault:
                        (card['is_default'] == 1 || card['is_default'] == true),
                    cardType: _getCardType(card['card_number']),
                  ))
              .toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading credit cards: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _addCreditCard(CreditCard card) async {
    setState(() {
      _isSaving = true;
    });

    try {
      // Enviar datos a la API para guardar la tarjeta de forma segura
      final response = await http.post(
        Uri.parse('${Config.baseUrl}/users/cards'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'user_email': widget.userEmail,
          'card_number': card.cardNumber,
          'card_holder': card.cardHolder,
          'expiry_date': card.expiryDate,
          'cvv': card.cvv,
          'is_default': card.isDefault,
          'card_type': card.cardType.toString().split('.').last,
          'document_type': card.documentType,
          'document_number': card.documentNumber,
        }),
      );

      if (response.statusCode == 200) {
        setState(() {
          _creditCards.add(card);
          _isSaving = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.t('card_saved')),
            backgroundColor: const Color(0xFF78BF32),
          ),
        );
      } else {
        throw Exception('Error al guardar la tarjeta');
      }
    } catch (e) {
      print('Error saving credit card: $e');
      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.t('error_saving_card')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteCreditCard(String id) async {
    final loc = AppLocalizations.of(context)!;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loc.t('delete_card')),
        content: Text(loc.t('confirm_delete')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(loc.t('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(loc.t('delete'),
                style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Enviar solicitud a la API para eliminar la tarjeta
        final response = await http.delete(
          Uri.parse('${Config.baseUrl}/users/cards/$id'),
        );

        if (response.statusCode == 200) {
          setState(() {
            _creditCards.removeWhere((card) => card.id == id);
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(loc.t('card_deleted')),
              backgroundColor: const Color(0xFF78BF32),
            ),
          );
        } else {
          throw Exception('Error al eliminar la tarjeta');
        }
      } catch (e) {
        print('Error deleting credit card: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.t('error_saving_card')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  CardType _getCardType(String cardNumber) {
    final cleaned = cardNumber.replaceAll(RegExp(r'\s+'), '');
    if (cleaned.startsWith('4')) {
      return CardType.visa;
    } else if (cleaned.startsWith('5')) {
      return CardType.mastercard;
    } else if (cleaned.startsWith('3')) {
      return CardType.amex;
    } else if (cleaned.startsWith('6')) {
      return CardType.discover;
    }
    return CardType.visa; // Default to Visa
  }

  Future<void> _setDefaultCard(String id) async {
    try {
      // Enviar solicitud a la API para establecer la tarjeta predeterminada
      final response = await http.put(
        Uri.parse('${Config.baseUrl}/users/cards/$id/default'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'user_email': widget.userEmail}),
      );

      if (response.statusCode == 200) {
        setState(() {
          for (var card in _creditCards) {
            card.isDefault = card.id == id;
          }
        });
      } else {
        throw Exception('Error al establecer la tarjeta predeterminada');
      }
    } catch (e) {
      print('Error setting default card: $e');
    }
  }

  Future<void> _showAddCardDialog() async {
    final result = await showDialog<CreditCard>(
      context: context,
      builder: (context) => _AddCardDialog(),
    );

    if (result != null) {
      await _addCreditCard(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: themeProvider.scaffoldBgColor,
      appBar: AppBar(
        backgroundColor: themeProvider.cardBgColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF78BF32)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          loc.t('my_cards'),
          style: TextStyle(
            color: themeProvider.textColor,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _creditCards.isEmpty
                ? _buildEmptyState(themeProvider, loc)
                : SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Lista de Tarjetas
                          ..._creditCards
                              .map((card) => _buildCreditCard(
                                    card,
                                    themeProvider,
                                    loc,
                                  ))
                              .toList(),

                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeProvider themeProvider, AppLocalizations loc) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.credit_card_off,
            size: 80,
            color: themeProvider.secondaryTextColor,
          ),
          const SizedBox(height: 24),
          Text(
            loc.t('no_cards'),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: themeProvider.textColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            loc.t('add_first_card'),
            style: TextStyle(
              fontSize: 16,
              color: themeProvider.secondaryTextColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _showAddCardDialog,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF78BF32),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 2,
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.add,
                    size: 24,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    loc.t('add_card'),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreditCard(
    CreditCard card,
    ThemeProvider themeProvider,
    AppLocalizations loc,
  ) {
    return GestureDetector(
      onTap: () {
        // Acción al hacer clic en la tarjeta
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        child: Stack(
          alignment: Alignment.bottomRight,
          children: [
            _CreditCardWidget(card: card),
            Positioned(
              bottom: -10,
              right: -10,
              child: PopupMenuButton<String>(
                icon: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF78BF32),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.more_vert,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                onSelected: (value) {
                  if (value == 'delete') {
                    _deleteCreditCard(card.id);
                  } else if (value == 'default') {
                    _setDefaultCard(card.id);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'default',
                    enabled: !card.isDefault,
                    child: Text(loc.t('set_default_card')),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      loc.t('delete_card'),
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddCardDialog extends StatefulWidget {
  @override
  State<_AddCardDialog> createState() => _AddCardDialogState();
}

class _AddCardDialogState extends State<_AddCardDialog> {
  final _formKey = GlobalKey<FormState>();
  final _cardNumberController = TextEditingController();
  final _cardHolderController = TextEditingController();
  final _expiryDateController = TextEditingController();
  final _cvvController = TextEditingController();
  final _documentController = TextEditingController();
  final _cvvFocusNode = FocusNode();
  bool _isDefault = false;
  String _documentType = 'C.C';
  bool _isCardFlipped = false;

  @override
  void initState() {
    super.initState();
    // Agregar listeners para actualizar la vista previa
    _cardNumberController.addListener(() => setState(() {}));
    _cardHolderController.addListener(() => setState(() {}));
    _expiryDateController.addListener(() => setState(() {}));
    _cvvController.addListener(() => setState(() {}));

    // Listener para voltear la tarjeta cuando el CVV tiene el foco
    _cvvFocusNode.addListener(() {
      setState(() {
        _isCardFlipped = _cvvFocusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _cardNumberController.dispose();
    _cardHolderController.dispose();
    _expiryDateController.dispose();
    _cvvController.dispose();
    _documentController.dispose();
    _cvvFocusNode.dispose();
    super.dispose();
  }

  // Formatear el número de tarjeta con # para los dígitos faltantes
  String _formatCardNumberWithHashes(String cardNumber) {
    // Eliminar espacios y caracteres no numéricos
    final cleaned = cardNumber.replaceAll(RegExp(r'[^\d]'), '');

    // Crear el número con # para los dígitos faltantes
    final buffer = StringBuffer();
    for (int i = 0; i < 16; i++) {
      if (i < cleaned.length) {
        buffer.write(cleaned[i]);
      } else {
        buffer.write('#');
      }
      // Agregar espacio cada 4 dígitos
      if ((i + 1) % 4 == 0 && i < 15) {
        buffer.write(' ');
      }
    }
    return buffer.toString();
  }

  // Formatear la fecha de vencimiento con placeholders
  String _formatExpiryDateWithPlaceholders(String expiryDate) {
    // Eliminar la barra y caracteres no numéricos
    final cleaned = expiryDate.replaceAll(RegExp(r'[^\d]'), '');

    // Crear la fecha con placeholders MM/AA
    final buffer = StringBuffer();
    for (int i = 0; i < 4; i++) {
      if (i == 2) {
        buffer.write('/');
      }
      if (i < cleaned.length) {
        buffer.write(cleaned[i]);
      } else if (i < 2) {
        buffer.write('M');
      } else {
        buffer.write('A');
      }
    }
    return buffer.toString();
  }

  // Detectar el tipo de tarjeta basado en el número
  CardType _detectCardType(String cardNumber) {
    final cleaned = cardNumber.replaceAll(RegExp(r'\s+'), '');
    if (cleaned.isEmpty) return CardType.unknown;

    // Visa: empieza con 4
    if (cleaned.startsWith('4')) {
      return CardType.visa;
    }
    // Mastercard: empieza con 51-55 o 2221-2720
    if (RegExp(r'^(5[1-5]|2[2-7][2-7][0-1])').hasMatch(cleaned)) {
      return CardType.mastercard;
    }
    // American Express: empieza con 34 o 37
    if (cleaned.startsWith('34') || cleaned.startsWith('37')) {
      return CardType.amex;
    }
    // Discover: empieza con 6011, 644-649, o 65
    if (cleaned.startsWith('6011') ||
        cleaned.startsWith('65') ||
        (cleaned.startsWith('64') && cleaned.length >= 3)) {
      final thirdDigit =
          cleaned.length >= 3 ? int.tryParse(cleaned.substring(2, 3)) : 0;
      if (cleaned.startsWith('6011') ||
          cleaned.startsWith('65') ||
          (cleaned.startsWith('64') &&
              thirdDigit != null &&
              thirdDigit >= 4 &&
              thirdDigit <= 9)) {
        return CardType.discover;
      }
    }
    // Diners Club: empieza con 300-305, 36, 38
    if (RegExp(r'^(30[0-5]|36|38)').hasMatch(cleaned)) {
      return CardType.diners;
    }
    // JCB: empieza con 35
    if (cleaned.startsWith('35')) {
      return CardType.jcb;
    }
    // UnionPay: empieza con 62
    if (cleaned.startsWith('62')) {
      return CardType.unionpay;
    }

    return CardType.unknown;
  }

  // Obtener la ruta del logo según el tipo de tarjeta
  String? _getCardLogoPath(CardType cardType) {
    switch (cardType) {
      case CardType.visa:
        return 'assets/images/cards/visa.png';
      case CardType.mastercard:
        return 'assets/images/cards/mastercard.png';
      case CardType.amex:
        return 'assets/images/cards/amex.png';
      case CardType.discover:
        return 'assets/images/cards/discover.png';
      case CardType.diners:
        return 'assets/images/cards/diners.png';
      case CardType.jcb:
        return 'assets/images/cards/jcb.png';
      case CardType.unionpay:
        return 'assets/images/cards/unionpay.png';
      case CardType.unknown:
      default:
        return null; // No mostrar logo si es desconocido
    }
  }

  String? _validateCardNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return AppLocalizations.of(context)!.t('card_number_required');
    }

    final cleaned = value.replaceAll(RegExp(r'\s+'), '');
    if (cleaned.length != 16) {
      return AppLocalizations.of(context)!.t('card_number_invalid');
    }

    // Validar que empiece con un prefijo válido de tarjeta conocida
    final firstDigit = cleaned[0];
    final firstTwoDigits = cleaned.substring(0, 2);
    final firstFourDigits = cleaned.substring(0, 4);

    bool isValidPrefix = false;

    // Visa: empieza con 4
    if (cleaned.startsWith('4')) {
      isValidPrefix = true;
    }
    // Mastercard: empieza con 51-55 o 2221-2720
    else if (RegExp(r'^(5[1-5]|2[2-7][2-7][0-1])').hasMatch(cleaned)) {
      isValidPrefix = true;
    }
    // American Express: empieza con 34 o 37
    else if (cleaned.startsWith('34') || cleaned.startsWith('37')) {
      isValidPrefix = true;
    }
    // Discover: empieza con 6011, 644-649, o 65
    else if (cleaned.startsWith('6011') ||
        cleaned.startsWith('65') ||
        (firstDigit == '6' &&
            int.tryParse(firstTwoDigits) != null &&
            int.parse(firstTwoDigits) >= 64 &&
            int.parse(firstTwoDigits) <= 65)) {
      isValidPrefix = true;
    }
    // Diners Club: empieza con 300-305, 36, 38
    else if (RegExp(r'^(30[0-5]|36|38)').hasMatch(cleaned)) {
      isValidPrefix = true;
    }
    // JCB: empieza con 35
    else if (cleaned.startsWith('35')) {
      isValidPrefix = true;
    }
    // UnionPay: empieza con 62
    else if (cleaned.startsWith('62')) {
      isValidPrefix = true;
    }

    if (!isValidPrefix) {
      return 'Número de tarjeta no válido';
    }

    return null;
  }

  String? _validateCardHolder(String? value) {
    if (value == null || value.trim().isEmpty) {
      return AppLocalizations.of(context)!.t('card_holder_required');
    }
    // Validar que no contenga números
    if (RegExp(r'[0-9]').hasMatch(value)) {
      return 'El nombre no puede contener números';
    }
    return null;
  }

  String? _validateExpiryDate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return AppLocalizations.of(context)!.t('expiry_date_required');
    }

    // Validar formato MM/AA (exactamente 2 dígitos para mes y 2 para año)
    final match = RegExp(r'^\d{2}/\d{2}$').hasMatch(value);
    if (!match) {
      return AppLocalizations.of(context)!.t('expiry_date_invalid');
    }

    // Validar que el mes esté entre 01 y 12
    final parts = value.split('/');
    final month = int.tryParse(parts[0]);
    if (month == null || month < 1 || month > 12) {
      return AppLocalizations.of(context)!.t('expiry_date_invalid');
    }

    // Validar que el año esté entre 26 y 99
    final year = int.tryParse(parts[1]);
    if (year == null || year < 26 || year > 99) {
      return AppLocalizations.of(context)!.t('expiry_date_invalid');
    }

    return null;
  }

  String? _validateCvv(String? value) {
    if (value == null || value.trim().isEmpty) {
      return AppLocalizations.of(context)!.t('cvv_required');
    }

    if (value.length < 3 || value.length > 4) {
      return AppLocalizations.of(context)!.t('cvv_invalid');
    }

    return null;
  }

  String? _validateDocument(String? value) {
    if (value == null || value.trim().isEmpty) {
      return AppLocalizations.of(context)!.t('document_required');
    }

    return null;
  }

  void _showDocumentTypePicker(
      ThemeProvider themeProvider, AppLocalizations loc) {
    final documentTypes = ['C.C', 'C.E', 'P.P'];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            decoration: BoxDecoration(
              color: themeProvider.cardBgColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: themeProvider.isDarkMode
                        ? Colors.grey[600]
                        : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    loc.t('select_type_via'),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: themeProvider.textColor,
                    ),
                  ),
                ),
                Divider(height: 1, color: themeProvider.borderColor),
                ...documentTypes.map((type) {
                  final isSelected = _documentType == type;
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _documentType = type;
                      });
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSelected
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                            color: isSelected
                                ? const Color(0xFF78BF32)
                                : themeProvider.secondaryTextColor,
                          ),
                          const SizedBox(width: 16),
                          Text(
                            type,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: isSelected
                                  ? const Color(0xFF78BF32)
                                  : themeProvider.textColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  // Construir el frente de la tarjeta
  Widget _buildFrontCardPreview(
      ThemeProvider themeProvider, AppLocalizations loc) {
    final cardType = _detectCardType(_cardNumberController.text);

    return Container(
      key: const ValueKey('front'),
      height: 200,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: cardType == CardType.visa
              ? [Colors.blue[600]!, Colors.blue[800]!]
              : cardType == CardType.mastercard
                  ? [Colors.orange[700]!, Colors.red[700]!]
                  : cardType == CardType.amex
                      ? [Colors.grey[700]!, Colors.grey[900]!]
                      : [Colors.blue[600]!, Colors.blue[800]!],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Icon(
                Icons.credit_card,
                color: Colors.white,
                size: 30,
              ),
              // Logo de la tarjeta
              if (_getCardLogoPath(cardType) != null)
                Container(
                  height: 35,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Image.asset(
                    _getCardLogoPath(cardType)!,
                    fit: BoxFit.contain,
                  ),
                ),
            ],
          ),
          Text(
            _formatCardNumberWithHashes(_cardNumberController.text),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              fontFamily: 'Courier',
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      loc.t('card_holder_label'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _cardHolderController.text.isNotEmpty
                            ? _cardHolderController.text
                            : loc.t('card_holder_hint'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              const SizedBox(width: 60),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    loc.t('expires_label'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    _formatExpiryDateWithPlaceholders(
                        _expiryDateController.text),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Construir el reverso de la tarjeta
  Widget _buildBackCardPreview(
      ThemeProvider themeProvider, AppLocalizations loc) {
    final cardType = _detectCardType(_cardNumberController.text);
    final cvvLength = _cvvController.text.length;
    final cvvDisplay = cvvLength > 0 ? '*' * cvvLength : '***';

    return Container(
      key: const ValueKey('back'),
      height: 200,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: cardType == CardType.visa
              ? [Colors.blue[700]!, Colors.blue[900]!]
              : cardType == CardType.mastercard
                  ? [Colors.orange[800]!, Colors.red[800]!]
                  : cardType == CardType.amex
                      ? [Colors.grey[800]!, Colors.grey[900]!]
                      : [Colors.blue[700]!, Colors.blue[900]!],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 30),
          // Banda magnética
          Container(
            height: 45,
            color: Colors.black,
          ),
          const SizedBox(height: 20),
          // CVV
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    alignment: Alignment.centerRight,
                    child: Text(
                      cvvDisplay,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                        fontFamily: 'Courier',
                      ),
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

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final loc = AppLocalizations.of(context)!;

    return AlertDialog(
      backgroundColor: themeProvider.scaffoldBgColor,
      title: Text(
        loc.t('add_card'),
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: themeProvider.textColor,
        ),
      ),
      contentPadding: const EdgeInsets.all(24),
      content: Container(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Vista previa de la tarjeta
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(
                    begin: 0.0,
                    end: _isCardFlipped ? 1.0 : 0.0,
                  ),
                  duration: const Duration(milliseconds: 600),
                  builder: (context, value, child) {
                    final angle = value * 3.14159;
                    final showFront = value < 0.5;

                    return Transform(
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.001)
                        ..rotateY(showFront ? angle : 3.14159 - angle),
                      alignment: Alignment.center,
                      child: showFront
                          ? _buildFrontCardPreview(themeProvider, loc)
                          : Transform(
                              transform: Matrix4.identity()..rotateY(3.14159),
                              alignment: Alignment.center,
                              child: _buildBackCardPreview(themeProvider, loc),
                            ),
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Número de Tarjeta
                TextFormField(
                  controller: _cardNumberController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    CardNumberFormatter(),
                  ],
                  style: TextStyle(color: themeProvider.textColor),
                  decoration: InputDecoration(
                    labelText: loc.t('card_number'),
                    labelStyle:
                        TextStyle(color: themeProvider.secondaryTextColor),
                    hintText: loc.t('card_number_hint'),
                    prefixIcon:
                        const Icon(Icons.credit_card, color: Color(0xFF78BF32)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: themeProvider.isDarkMode
                            ? Colors.grey[600]!
                            : Colors.grey[300]!,
                      ),
                    ),
                    filled: true,
                    fillColor: themeProvider.isDarkMode
                        ? Colors.grey[800]!
                        : Colors.white,
                  ),
                  validator: _validateCardNumber,
                ),
                const SizedBox(height: 16),

                // Titular de la Tarjeta
                TextFormField(
                  controller: _cardHolderController,
                  style: TextStyle(color: themeProvider.textColor),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ\s]')),
                  ],
                  decoration: InputDecoration(
                    labelText: loc.t('card_holder'),
                    labelStyle:
                        TextStyle(color: themeProvider.secondaryTextColor),
                    hintText: loc.t('card_holder_hint'),
                    prefixIcon:
                        const Icon(Icons.person, color: Color(0xFF78BF32)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: themeProvider.isDarkMode
                            ? Colors.grey[600]!
                            : Colors.grey[300]!,
                      ),
                    ),
                    filled: true,
                    fillColor: themeProvider.isDarkMode
                        ? Colors.grey[800]!
                        : Colors.white,
                  ),
                  validator: _validateCardHolder,
                ),
                const SizedBox(height: 16),

                // Fecha de Expiración y CVV
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _expiryDateController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          ExpiryDateFormatter(),
                        ],
                        style: TextStyle(color: themeProvider.textColor),
                        decoration: InputDecoration(
                          labelText: loc.t('expiry_date'),
                          labelStyle: TextStyle(
                              color: themeProvider.secondaryTextColor),
                          hintText: loc.t('expiry_date_hint'),
                          prefixIcon: const Icon(Icons.calendar_today,
                              color: Color(0xFF78BF32)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: themeProvider.isDarkMode
                                  ? Colors.grey[600]!
                                  : Colors.grey[300]!,
                            ),
                          ),
                          filled: true,
                          fillColor: themeProvider.isDarkMode
                              ? Colors.grey[800]!
                              : Colors.white,
                        ),
                        validator: _validateExpiryDate,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _cvvController,
                        focusNode: _cvvFocusNode,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                        ],
                        style: TextStyle(color: themeProvider.textColor),
                        decoration: InputDecoration(
                          labelText: loc.t('cvv'),
                          labelStyle: TextStyle(
                              color: themeProvider.secondaryTextColor),
                          hintText: loc.t('cvv_hint'),
                          prefixIcon: const Icon(Icons.security,
                              color: Color(0xFF78BF32)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: themeProvider.isDarkMode
                                  ? Colors.grey[600]!
                                  : Colors.grey[300]!,
                            ),
                          ),
                          filled: true,
                          fillColor: themeProvider.isDarkMode
                              ? Colors.grey[800]!
                              : Colors.white,
                        ),
                        validator: _validateCvv,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Documento del Titular
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => _showDocumentTypePicker(themeProvider, loc),
                      child: Container(
                        width: 100,
                        decoration: BoxDecoration(
                          color: themeProvider.isDarkMode
                              ? Colors.grey[800]!
                              : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: themeProvider.isDarkMode
                                ? Colors.grey[600]!
                                : Colors.grey[300]!,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _documentType,
                              style: TextStyle(color: themeProvider.textColor),
                            ),
                            const Icon(Icons.keyboard_arrow_up,
                                color: Color(0xFF78BF32), size: 20),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _documentController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        style: TextStyle(color: themeProvider.textColor),
                        decoration: InputDecoration(
                          labelText: loc.t('document'),
                          labelStyle: TextStyle(
                              color: themeProvider.secondaryTextColor),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: themeProvider.isDarkMode
                                  ? Colors.grey[600]!
                                  : Colors.grey[300]!,
                            ),
                          ),
                          filled: true,
                          fillColor: themeProvider.isDarkMode
                              ? Colors.grey[800]!
                              : Colors.white,
                        ),
                        validator: _validateDocument,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Tarjeta Predeterminada
                Container(
                  decoration: BoxDecoration(
                    color: themeProvider.cardBgColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: themeProvider.isDarkMode
                            ? Colors.black.withOpacity(0.2)
                            : Colors.grey.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 3,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: CheckboxListTile(
                    value: _isDefault,
                    onChanged: (value) {
                      setState(() {
                        _isDefault = value!;
                      });
                    },
                    title: Text(
                      loc.t('default_card'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: themeProvider.textColor,
                      ),
                    ),
                    subtitle: Text(
                      loc.t('default_card_description'),
                      style: TextStyle(
                        fontSize: 12,
                        color: themeProvider.secondaryTextColor,
                      ),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: const Color(0xFF78BF32),
                    checkColor: Colors.white,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
                const SizedBox(height: 24),

                // Botones Cancelar y Agregar
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: themeProvider.cardBgColor,
                            foregroundColor: themeProvider.textColor,
                            side: BorderSide(color: themeProvider.borderColor),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: Text(
                            loc.t('cancel'),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.only(left: 8),
                        child: ElevatedButton(
                          onPressed: () {
                            if (_formKey.currentState!.validate()) {
                              final cardNumber = _cardNumberController.text
                                  .replaceAll(RegExp(r'\s+'), '');
                              final expiryDate = _expiryDateController.text;
                              final cvv = _cvvController.text;
                              final cardHolder =
                                  _cardHolderController.text.trim();

                              final card = CreditCard(
                                id: DateTime.now()
                                    .millisecondsSinceEpoch
                                    .toString(),
                                cardNumber: _formatCardNumber(cardNumber),
                                cardHolder: cardHolder,
                                expiryDate: expiryDate,
                                cvv: cvv,
                                isDefault: _isDefault,
                                cardType: _getCardType(cardNumber),
                                documentType: _documentType,
                                documentNumber: _documentController.text,
                              );

                              Navigator.pop(context, card);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF78BF32),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: Text(
                            loc.t('add_card'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatCardNumber(String number) {
    final formatted = number.replaceAllMapped(
        RegExp(r'.{4}'), (match) => '${match.group(0)} ');
    return formatted.trim();
  }

  CardType _getCardType(String number) {
    if (number.startsWith('4')) {
      return CardType.visa;
    } else if (number.startsWith('5')) {
      return CardType.mastercard;
    }
    return CardType.visa; // Default to Visa
  }
}

class _CreditCardWidget extends StatefulWidget {
  final CreditCard card;

  const _CreditCardWidget({required this.card});

  @override
  State<_CreditCardWidget> createState() => _CreditCardWidgetState();
}

class _CreditCardWidgetState extends State<_CreditCardWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _frontRotation;
  late Animation<double> _backRotation;
  bool _isFlipped = false;

  // Obtener la ruta del logo según el tipo de tarjeta
  String? _getCardLogoPath(CardType cardType) {
    switch (cardType) {
      case CardType.visa:
        return 'assets/images/cards/visa.png';
      case CardType.mastercard:
        return 'assets/images/cards/mastercard.png';
      case CardType.amex:
        return 'assets/images/cards/amex.png';
      case CardType.discover:
        return 'assets/images/cards/discover.png';
      case CardType.diners:
        return 'assets/images/cards/diners.png';
      case CardType.jcb:
        return 'assets/images/cards/jcb.png';
      case CardType.unionpay:
        return 'assets/images/cards/unionpay.png';
      case CardType.unknown:
      default:
        return null; // No mostrar logo si es desconocido
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _frontRotation = TweenSequence<double>([
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 0.0, end: -0.5),
        weight: 50,
      ),
      TweenSequenceItem<double>(
        tween: ConstantTween<double>(-0.5),
        weight: 50,
      ),
    ]).animate(_controller);

    _backRotation = TweenSequence<double>([
      TweenSequenceItem<double>(
        tween: ConstantTween<double>(0.5),
        weight: 50,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 0.5, end: 0.0),
        weight: 50,
      ),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _flipCard() {
    if (_isFlipped) {
      _controller.reverse();
    } else {
      _controller.forward();
    }
    _isFlipped = !_isFlipped;
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final loc = AppLocalizations.of(context)!;

    return GestureDetector(
      onTap: _flipCard,
      child: SizedBox(
        height: 200,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Stack(
              children: [
                Transform(
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..rotateY(_frontRotation.value * 3.1415),
                  alignment: Alignment.center,
                  child: _buildFrontCard(themeProvider, loc),
                ),
                Transform(
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..rotateY(_backRotation.value * 3.1415),
                  alignment: Alignment.center,
                  child: _buildBackCard(themeProvider),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildFrontCard(ThemeProvider themeProvider, AppLocalizations loc) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: widget.card.cardType == CardType.visa
              ? [const Color(0xFF1a1a2e), const Color(0xFF16213e)]
              : widget.card.cardType == CardType.mastercard
                  ? [const Color(0xFFf72585), const Color(0xFF7209b7)]
                  : widget.card.cardType == CardType.amex
                      ? [const Color(0xFF4a4a4a), const Color(0xFF2a2a2a)]
                      : [Colors.blue[600]!, Colors.blue[800]!],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logotipo de la tarjeta
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Icon(
                Icons.credit_card,
                color: Colors.white,
                size: 30,
              ),
              Container(
                height: 35,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _getCardLogoPath(widget.card.cardType) != null
                    ? Image.asset(
                        _getCardLogoPath(widget.card.cardType)!,
                        fit: BoxFit.contain,
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
          // Número de tarjeta
          Text(
            widget.card.cardNumber,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              fontFamily: 'Courier',
            ),
          ),
          // Datos del titular y fecha de expiración
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      loc.t('card_holder_label'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        widget.card.cardHolder,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    loc.t('expires_label'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    widget.card.expiryDate,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBackCard(ThemeProvider themeProvider) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: widget.card.cardType == CardType.visa
              ? [const Color(0xFF16213e), const Color(0xFF1a1a2e)]
              : [const Color(0xFF7209b7), const Color(0xFFf72585)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Barra magnética
          Container(
            height: 50,
            width: double.infinity,
            color: Colors.black,
            margin: const EdgeInsets.only(bottom: 20),
          ),
          // CVV
          Container(
            height: 40,
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'CVV',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  widget.card.cvv,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    fontFamily: 'Courier',
                  ),
                ),
              ],
            ),
          ),
          // Logotipo
          Align(
            alignment: Alignment.bottomRight,
            child: Text(
              widget.card.cardType == CardType.visa ? 'VISA' : 'MASTERCARD',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CreditCard {
  final String id;
  String cardNumber;
  String cardHolder;
  String expiryDate;
  String cvv;
  bool isDefault;
  final CardType cardType;
  String documentType;
  String documentNumber;

  CreditCard({
    required this.id,
    required this.cardNumber,
    required this.cardHolder,
    required this.expiryDate,
    required this.cvv,
    required this.isDefault,
    required this.cardType,
    this.documentType = 'C.C',
    this.documentNumber = '',
  });
}

enum CardType {
  visa,
  mastercard,
  amex,
  discover,
  diners,
  jcb,
  unionpay,
  unknown,
}

class CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text;
    var selection = newValue.selection;

    if (text.length <= 16) {
      var formattedText = '';
      for (var i = 0; i < text.length; i++) {
        if (i > 0 && i % 4 == 0) {
          formattedText += ' ';
        }
        formattedText += text[i];
      }

      var newSelection = TextSelection(
        baseOffset: formattedText.length,
        extentOffset: formattedText.length,
      );

      return TextEditingValue(
        text: formattedText,
        selection: newSelection,
        composing: TextRange.empty,
      );
    }

    return oldValue;
  }
}

class ExpiryDateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    // Solo permitir dígitos
    var text = newValue.text.replaceAll(RegExp(r'[^\d]'), '');

    // Limitar a 4 dígitos (MMYY)
    if (text.length > 4) {
      text = text.substring(0, 4);
    }

    // Formatear con barra: MM/YY
    var formattedText = '';
    for (var i = 0; i < text.length; i++) {
      if (i == 2 && text.length > 2) {
        formattedText += '/';
      }
      formattedText += text[i];
    }

    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: formattedText.length),
      composing: TextRange.empty,
    );
  }
}
