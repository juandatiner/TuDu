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
    with TickerProviderStateMixin {
  List<CreditCard> _creditCards = [];
  bool _isLoading = true;
  bool _isSaving = false;

  // Para animaciones de reordenamiento de tarjetas
  String? _animatingCardId;
  bool _isMovingUp = false;

  // Tarjeta seleccionada para mostrar acciones
  String? _selectedCardId;

  // Para animaciones de entrada y salida de tarjetas
  Map<String, bool> _cardExitAnimations = {};
  String? _enteringCardId; // ID de la tarjeta que está entrando

  @override
  void initState() {
    super.initState();
    _loadCreditCards();
  }

  Future<void> _loadCreditCards() async {
    try {
      // Cargar las tarjetas del usuario desde el backend
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
                    // CVV no se almacena por seguridad
                    isDefault:
                        (card['is_default'] == 1 || card['is_default'] == true),
                    cardType: _getCardType(card['card_number']),
                    documentType: card['document_type'] ?? 'C.C',
                    documentNumber: card['document_number'] ?? '',
                    createdAt: card['created_at'] ?? '',
                    cardMode: card['card_mode'] ?? 'credit',
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

  // Obtener la tarjeta favorita
  CreditCard? get _favoriteCard {
    try {
      return _creditCards.firstWhere((card) => card.isDefault);
    } catch (e) {
      return null;
    }
  }

  // Obtener las otras tarjetas (excluyendo la favorita), ordenadas de nueva a antigua
  List<CreditCard> get _otherCards {
    final otherCards = _creditCards.where((card) => !card.isDefault).toList();
    // Ordenar por fecha de creación descendente (más nueva primero)
    otherCards.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return otherCards;
  }

  Future<void> _addCreditCard(CreditCard card) async {
    setState(() {
      _isSaving = true;
    });

    try {
      // Enviar datos a la API para guardar la tarjeta de forma segura
      // NOTA: El CVV no se envía ni almacena por seguridad (PCI-DSS)
      final response = await http.post(
        Uri.parse('${Config.baseUrl}/users/cards'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'user_email': widget.userEmail,
          'card_number': card.cardNumber,
          'card_holder': card.cardHolder,
          'expiry_date': card.expiryDate,
          // CVV no se envía por seguridad
          'is_default': card.isDefault,
          'card_type': card.cardType.toString().split('.').last,
          'document_type': card.documentType,
          'document_number': card.documentNumber,
          'card_mode': card.cardMode,
        }),
      );

      if (response.statusCode == 200) {
        // Recargar las tarjetas desde la base de datos
        await _loadCreditCards();

        // Determinar qué tarjeta es la nueva (puede ser favorita o no)
        String? newCardId;
        if (card.isDefault && _favoriteCard != null) {
          // Si la nueva tarjeta es favorita, animar la tarjeta favorita
          newCardId = _favoriteCard!.id;
        } else if (_otherCards.isNotEmpty) {
          // Si no es favorita, la nueva tarjeta será la primera en otras tarjetas
          newCardId = _otherCards.first.id;
        }

        if (newCardId != null) {
          // Marcar la tarjeta como entrante (se animará con TweenAnimationBuilder)
          setState(() {
            _enteringCardId = newCardId;
          });

          // Remover la animación después de que termine
          await Future.delayed(const Duration(milliseconds: 400));
          setState(() {
            _enteringCardId = null;
          });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.t('card_saved')),
            backgroundColor: const Color(0xFF78BF32),
          ),
        );
      } else {
        final errorData = json.decode(response.body);
        final errorMessage =
            errorData['error'] ?? 'Error al guardar la tarjeta';
        throw Exception(errorMessage);
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
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    // Verificar si la tarjeta a eliminar es la favorita
    final cardToDelete = _creditCards.firstWhere((card) => card.id == id);
    final wasFavorite = cardToDelete.isDefault;

    // Primero cerrar la tarjeta seleccionada
    setState(() {
      _selectedCardId = null;
    });

    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: themeProvider.cardBgColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Título
              Text(
                loc.t('delete_card'),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: themeProvider.textColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Mensaje
              Text(
                loc.t('confirm_delete'),
                style: TextStyle(
                  fontSize: 16,
                  color: themeProvider.secondaryTextColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Botones
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeProvider.cardBgColor,
                        foregroundColor: themeProvider.textColor,
                        side: BorderSide(color: themeProvider.borderColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        loc.t('cancel'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        loc.t('delete'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
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
    );

    if (confirmed == true) {
      // Iniciar animación de salida (deslizamiento a la izquierda) DESPUÉS de confirmar
      setState(() {
        _cardExitAnimations[id] = true;
      });

      // Esperar a que termine la animación
      await Future.delayed(const Duration(milliseconds: 300));

      try {
        // Enviar solicitud a la API para eliminar la tarjeta
        final response = await http.delete(
          Uri.parse('${Config.baseUrl}/users/cards/$id'),
        );

        if (response.statusCode == 200) {
          // Eliminar la tarjeta localmente después de la animación
          setState(() {
            _creditCards.removeWhere((card) => card.id == id);
            _cardExitAnimations.remove(id);
          });

          // Si la tarjeta eliminada era la favorita y quedan tarjetas, asignar nueva favorita
          if (wasFavorite && _creditCards.isNotEmpty) {
            final newFavoriteCard = _creditCards.first;
            await _setFavoriteCard(newFavoriteCard.id);
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(loc.t('card_deleted')),
              backgroundColor: const Color(0xFF78BF32),
            ),
          );
        } else {
          // Revertir animación si hay error
          setState(() {
            _cardExitAnimations.remove(id);
          });
          throw Exception('Error al eliminar la tarjeta');
        }
      } catch (e) {
        print('Error deleting credit card: $e');
        // Revertir animación si hay error
        setState(() {
          _cardExitAnimations.remove(id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.t('error_saving_card')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      // Si cancela, no hay animación que revertir
    }
  }

  CardType _getCardType(String cardNumber) {
    final cleaned = cardNumber.replaceAll(RegExp(r'\s+'), '');
    if (cleaned.isEmpty) return CardType.unknown;

    // Visa: empieza con 4
    if (cleaned.startsWith('4')) {
      return CardType.visa;
    }
    // Mastercard: empieza con 51-55 o 2221-2720
    if (RegExp(r'^5[1-5]').hasMatch(cleaned)) {
      return CardType.mastercard;
    }
    if (cleaned.length >= 4 && cleaned.startsWith('2')) {
      final firstFour = int.tryParse(cleaned.substring(0, 4));
      if (firstFour != null && firstFour >= 2221 && firstFour <= 2720) {
        return CardType.mastercard;
      }
    }
    // American Express: empieza con 34 o 37
    if (cleaned.startsWith('34') || cleaned.startsWith('37')) {
      return CardType.amex;
    }
    // Discover: empieza con 6011, 644-649, o 65
    if (cleaned.startsWith('6011') || cleaned.startsWith('65')) {
      return CardType.discover;
    }
    if (cleaned.startsWith('64') && cleaned.length >= 3) {
      final thirdDigit = int.tryParse(cleaned.substring(2, 3));
      if (thirdDigit != null && thirdDigit >= 4 && thirdDigit <= 9) {
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

  Future<void> _setFavoriteCard(String id) async {
    // Encontrar la tarjeta que se va a hacer favorita
    final cardToMakeFavorite = _creditCards.firstWhere((card) => card.id == id);
    final currentFavoriteCard = _favoriteCard;

    // Deseleccionar la tarjeta actual
    setState(() {
      _selectedCardId = null;
    });

    try {
      // Enviar solicitud a la API para establecer la tarjeta favorita
      final response = await http.put(
        Uri.parse('${Config.baseUrl}/users/cards/$id/default'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'user_email': widget.userEmail}),
      );

      if (response.statusCode == 200) {
        // Recargar las tarjetas desde la base de datos
        await _loadCreditCards();
      } else {
        throw Exception('Error al establecer la tarjeta favorita');
      }
    } catch (e) {
      print('Error setting favorite card: $e');
    }
  }

  Future<void> _showAddCardDialog() async {
    final loc = AppLocalizations.of(context)!;

    // Verificar si ya tiene 7 tarjetas
    if (_creditCards.length >= 7) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.t('max_cards_reached')),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    final isFirstCard = _creditCards.isEmpty;
    final result = await showDialog<CreditCard>(
      context: context,
      builder: (context) => _AddCardDialog(
        isFirstCard: isFirstCard,
        existingCards: _creditCards,
      ),
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
                : _buildWalletCards(themeProvider, loc),
      ),
      floatingActionButton: _creditCards.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _showAddCardDialog,
              backgroundColor: const Color(0xFF78BF32),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add, size: 24),
              label: Text(
                loc.t('add_card'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
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

  // Construir las tarjetas en formato billetera (apiladas)
  Widget _buildWalletCards(ThemeProvider themeProvider, AppLocalizations loc) {
    return SingleChildScrollView(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Contenedor de tarjetas con altura fija suficiente para expandirse
              SizedBox(
                width: 317,
                height: 200 +
                    (_otherCards.length * 60.0) +
                    145.0, // Altura fija máxima (siempre con espacio para expansión)
                child: Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    // Otras tarjetas (arriba, detrás) - orden invertido
                    ..._otherCards.reversed
                        .toList()
                        .asMap()
                        .entries
                        .map((entry) {
                      final index = entry.key;
                      final card = entry.value;
                      final isSelected = _selectedCardId == card.id;
                      final isExiting = _cardExitAnimations[card.id] == true;
                      final isEntering = _enteringCardId == card.id;

                      // Calcular desplazamiento según si esta tarjeta está seleccionada o si otra está seleccionada
                      double topPosition = 60.0 * index;
                      if (_selectedCardId != null) {
                        final selectedCardIndex = _otherCards.reversed
                            .toList()
                            .indexWhere((c) => c.id == _selectedCardId);

                        if (selectedCardIndex != -1) {
                          if (index > selectedCardIndex) {
                            // Tarjeta está abajo de la seleccionada - mover hacia abajo
                            topPosition += 145.0;
                          }
                          // Si index < selectedCardIndex o es la seleccionada, mantener posición
                        }
                      }

                      return AnimatedPositioned(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        top: topPosition,
                        left: 0,
                        right: 0,
                        child: _AnimatedCard(
                          key: ValueKey(card.id),
                          isExiting: isExiting,
                          isEntering: isEntering,
                          child: _buildWalletCard(
                            card,
                            themeProvider,
                            loc,
                            isSelected: isSelected,
                            onTap: () => _onCardTap(card.id),
                          ),
                        ),
                      );
                    }),
                    // Tarjeta favorita (abajo, al frente) - última para que se renderice encima
                    if (_favoriteCard != null)
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        top: (_otherCards.length * 60.0) +
                            // Si hay una tarjeta seleccionada que NO es la favorita, mover hacia abajo
                            (_selectedCardId != null &&
                                    _selectedCardId != _favoriteCard!.id
                                ? 145.0
                                : 0.0),
                        left: 0,
                        right: 0,
                        child: Transform.translate(
                          offset: const Offset(-10, 0),
                          child: _AnimatedCard(
                            key: ValueKey(_favoriteCard!.id),
                            isExiting:
                                _cardExitAnimations[_favoriteCard!.id] == true,
                            isEntering: _enteringCardId == _favoriteCard!.id,
                            child: _buildWalletCard(
                              _favoriteCard!,
                              themeProvider,
                              loc,
                              isSelected: _selectedCardId == _favoriteCard!.id,
                              onTap: () => _onCardTap(_favoriteCard!.id),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  // Manejar el tap en una tarjeta
  void _onCardTap(String cardId) {
    setState(() {
      if (_selectedCardId == cardId) {
        _selectedCardId = null; // Deseleccionar si ya estaba seleccionada
      } else {
        _selectedCardId = cardId; // Seleccionar la nueva tarjeta
      }
    });
  }

  // Manejar el long press en una tarjeta (eliminar)
  void _onCardLongPress(String cardId) {
    _deleteCreditCard(cardId);
  }

  // Construir una tarjeta individual en formato billetera
  Widget _buildWalletCard(
    CreditCard card,
    ThemeProvider themeProvider,
    AppLocalizations loc, {
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    // Determinar si esta tarjeta está siendo animada
    final isAnimating = _animatingCardId == card.id;
    final isMovingUp = _isMovingUp;

    // Determinar la escala de la tarjeta según si es favorita o no
    final isFavorite = card.isDefault;
    final scale =
        isFavorite ? 1.0 : 0.95; // Tarjetas detrás son un poco más pequeñas

    // Si la tarjeta no está seleccionada y no es favorita, solo mostrar la parte superior
    final showTopOnly = !isSelected && !isFavorite;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOutCubic,
      transform: Matrix4.identity()
        ..translate(
          0.0,
          isAnimating ? (isMovingUp ? -30.0 : 30.0) : 0.0,
        )
        ..scale(isAnimating ? 0.95 : scale),
      margin: EdgeInsets.only(bottom: isAnimating ? 40.0 : 0.0),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 400),
        opacity: isAnimating ? 0.6 : 1.0,
        child: SizedBox(
          width: 317,
          child: showTopOnly
              ? _buildCardTopSection(
                  card, themeProvider, onTap, () => _onCardLongPress(card.id))
              : _CreditCardWidget(
                  card: card,
                  isSelected: isSelected,
                  onTap: onTap,
                  onLongPress: () => _onCardLongPress(card.id),
                  onFavoriteTap:
                      card.isDefault ? null : () => _setFavoriteCard(card.id),
                  onDeleteTap: () => _deleteCreditCard(card.id),
                ),
        ),
      ),
    );
  }

  // Construir solo la parte superior de la tarjeta (logo) para tarjetas apiladas
  Widget _buildCardTopSection(
    CreditCard card,
    ThemeProvider themeProvider,
    VoidCallback onTap,
    VoidCallback? onLongPress,
  ) {
    final loc = AppLocalizations.of(context)!;
    final cardColors = _getCardColors(card.cardType);
    final logoPath = _getCardLogoPath(card.cardType);

    // Mask the card number: show first 4 digits as **** and last 4 digits
    String maskedCardNumber =
        '**** **** **** ${card.cardNumber.split(' ').last}';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: cardColors,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            height: 200,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SizedBox(
                  height: 35,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Masked card number
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            maskedCardNumber,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                              fontFamily: 'Courier',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Card logo y tipo (crédito/débito)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Badge de crédito/débito
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              card.cardMode == 'credit'
                                  ? loc.t('credit')
                                  : loc.t('debit'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Card logo
                          if (logoPath != null)
                            Container(
                              height: 25,
                              width: 40,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Image.asset(
                                logoPath,
                                fit: BoxFit.contain,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Obtener colores según el tipo de tarjeta (copiado desde _CreditCardWidget)
  List<Color> _getCardColors(CardType cardType) {
    switch (cardType) {
      case CardType.visa:
        return [
          const Color(0xFF1A1F71),
          const Color(0xFF0D47A1)
        ]; // Azul oscuro Visa
      case CardType.mastercard:
        return [
          const Color(0xFFEB001B),
          const Color(0xFFF79E1B)
        ]; // Rojo/Naranja Mastercard
      case CardType.amex:
        return [
          const Color(0xFF006FCF),
          const Color(0xFF00AEFF)
        ]; // Azul American Express
      case CardType.discover:
        return [
          const Color(0xFFFFB300),
          const Color(0xFFFFD54F)
        ]; // Amarillo Discover
      case CardType.diners:
        return [
          const Color(0xFF0079BE),
          const Color(0xFF004B87)
        ]; // Azul Diners Club
      case CardType.jcb:
        return [const Color(0xFF00875A), const Color(0xFF00B4D8)]; // Verde JCB
      case CardType.unionpay:
        return [
          const Color(0xFFE21836),
          const Color(0xFF00447C)
        ]; // Rojo/Azul UnionPay
      case CardType.unknown:
      default:
        return [
          const Color(0xFF6B7280),
          const Color(0xFF374151)
        ]; // Gris para desconocida
    }
  }

  // Obtener la ruta del logo según el tipo de tarjeta (copiado desde _CreditCardWidget)
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
}

class _AddCardDialog extends StatefulWidget {
  final bool isFirstCard;
  final List<CreditCard> existingCards;

  const _AddCardDialog(
      {this.isFirstCard = false, this.existingCards = const []});

  @override
  State<_AddCardDialog> createState() => _AddCardDialogState();
}

class _AddCardDialogState extends State<_AddCardDialog> {
  final _formKey = GlobalKey<FormState>();
  final _cardNumberController = TextEditingController();
  final _cardHolderController = TextEditingController();
  final _expiryDateController = TextEditingController();
  final _documentController = TextEditingController();
  late bool _isDefault;
  String _documentType = 'C.C';
  String _cardMode = 'credit'; // 'credit' o 'debit'

  @override
  void initState() {
    super.initState();
    // Si es la primera tarjeta, será predeterminada automáticamente
    _isDefault = widget.isFirstCard;
    // Agregar listeners para actualizar la vista previa
    _cardNumberController.addListener(() => setState(() {}));
    _cardHolderController.addListener(() => setState(() {}));
    _expiryDateController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _cardNumberController.dispose();
    _cardHolderController.dispose();
    _expiryDateController.dispose();
    _documentController.dispose();
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
    // Rango 51-55
    if (RegExp(r'^5[1-5]').hasMatch(cleaned)) {
      return CardType.mastercard;
    }
    // Rango 2221-2720 (necesitamos al menos 4 dígitos)
    if (cleaned.length >= 4 && cleaned.startsWith('2')) {
      final firstFour = int.tryParse(cleaned.substring(0, 4));
      if (firstFour != null && firstFour >= 2221 && firstFour <= 2720) {
        return CardType.mastercard;
      }
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

    // Verificar si ya existe una tarjeta con el mismo número
    final normalizedNewCardNumber = cleaned;
    final exists = widget.existingCards.any((existingCard) {
      final normalizedExistingNumber =
          existingCard.cardNumber.replaceAll(RegExp(r'\s+'), '');
      return normalizedExistingNumber == normalizedNewCardNumber;
    });

    if (exists) {
      return AppLocalizations.of(context)!.t('card_already_exists');
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
    else if (RegExp(r'^5[1-5]').hasMatch(cleaned)) {
      isValidPrefix = true;
    }
    // Mastercard rango 2221-2720
    else if (cleaned.length >= 4 && cleaned.startsWith('2')) {
      final firstFour = int.tryParse(cleaned.substring(0, 4));
      if (firstFour != null && firstFour >= 2221 && firstFour <= 2720) {
        isValidPrefix = true;
      }
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

  String? _validateDocument(String? value) {
    if (value == null || value.trim().isEmpty) {
      return AppLocalizations.of(context)!.t('document_required');
    }

    return null;
  }

  void _showDocumentTypePicker(
      ThemeProvider themeProvider, AppLocalizations loc) {
    final documentTypes = ['C.C', 'C.E', 'P.P', 'Pasaporte'];

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
                        horizontal: 12,
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
                          const SizedBox(width: 12),
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
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

  // Mostrar selector de tipo de tarjeta (Crédito/Débito)
  void _showCardModePicker(ThemeProvider themeProvider, AppLocalizations loc) {
    final cardModes = [
      {'value': 'credit', 'label': loc.t('credit'), 'icon': Icons.credit_card},
      {'value': 'debit', 'label': loc.t('debit'), 'icon': Icons.payment},
    ];

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
                    loc.t('card_type_label'),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: themeProvider.textColor,
                    ),
                  ),
                ),
                Divider(height: 1, color: themeProvider.borderColor),
                ...cardModes.map((mode) {
                  final isSelected = _cardMode == mode['value'];
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _cardMode = mode['value'] as String;
                      });
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
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
                          const SizedBox(width: 12),
                          Icon(
                            mode['icon'] as IconData,
                            color: isSelected
                                ? const Color(0xFF78BF32)
                                : themeProvider.textColor,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                mode['label'] as String,
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

  // Obtener colores según el tipo de tarjeta
  List<Color> _getCardColors(CardType cardType) {
    switch (cardType) {
      case CardType.visa:
        return [
          const Color(0xFF1A1F71),
          const Color(0xFF0D47A1)
        ]; // Azul oscuro Visa
      case CardType.mastercard:
        return [
          const Color(0xFFEB001B),
          const Color(0xFFF79E1B)
        ]; // Rojo/Naranja Mastercard
      case CardType.amex:
        return [
          const Color(0xFF006FCF),
          const Color(0xFF00AEFF)
        ]; // Azul American Express
      case CardType.discover:
        return [
          const Color(0xFFFFB300),
          const Color(0xFFFFD54F)
        ]; // Amarillo Discover
      case CardType.diners:
        return [
          const Color(0xFF0079BE),
          const Color(0xFF004B87)
        ]; // Azul Diners Club
      case CardType.jcb:
        return [const Color(0xFF00875A), const Color(0xFF00B4D8)]; // Verde JCB
      case CardType.unionpay:
        return [
          const Color(0xFFE21836),
          const Color(0xFF00447C)
        ]; // Rojo/Azul UnionPay
      case CardType.unknown:
      default:
        return [
          const Color(0xFF6B7280),
          const Color(0xFF374151)
        ]; // Gris para desconocida
    }
  }

  // Construir el frente de la tarjeta
  Widget _buildFrontCardPreview(
      ThemeProvider themeProvider, AppLocalizations loc) {
    final cardType = _detectCardType(_cardNumberController.text);
    final cardColors = _getCardColors(cardType);

    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          key: const ValueKey('front'),
          height: 200,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: cardColors,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SizedBox(
                height: 35,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _cardMode == 'credit'
                            ? loc.t('credit')
                            : loc.t('debit'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    // Logo de la tarjeta - tamaño uniforme
                    if (_getCardLogoPath(cardType) != null)
                      Container(
                        height: 30,
                        width: 50,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Image.asset(
                          _getCardLogoPath(cardType)!,
                          fit: BoxFit.contain,
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _formatCardNumberWithHashes(_cardNumberController.text),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      fontFamily: 'Courier',
                    ),
                  ),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
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
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _cardHolderController.text.trim().isNotEmpty
                                ? _cardHolderController.text
                                    .trim()
                                    .toUpperCase()
                                    .substring(
                                        0,
                                        _cardHolderController.text
                                                    .trim()
                                                    .length >
                                                20
                                            ? 20
                                            : _cardHolderController.text
                                                .trim()
                                                .length)
                                : loc.t('card_holder_hint'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Column(
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
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
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
                // Vista previa de la tarjeta (solo frente, sin CVV)
                _buildFrontCardPreview(themeProvider, loc),
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
                    errorStyle: TextStyle(
                      fontSize: 12,
                      color: Colors.red,
                    ),
                    errorMaxLines: 2,
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
                    LengthLimitingTextInputFormatter(20),
                    _TrimLeftFormatter(),
                    _UpperCaseFormatter(),
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
                    errorStyle: TextStyle(
                      fontSize: 12,
                      color: Colors.red,
                    ),
                    errorMaxLines: 2,
                  ),
                  validator: _validateCardHolder,
                ),
                const SizedBox(height: 16),

                // Fecha de Expiración y Tipo de Tarjeta (Crédito/Débito)
                Row(
                  children: [
                    // Fecha de Expiración
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
                          errorStyle: TextStyle(
                            fontSize: 10,
                            color: Colors.red,
                          ),
                          errorMaxLines: 2,
                        ),
                        validator: _validateExpiryDate,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Dropdown de Crédito/Débito
                    GestureDetector(
                      onTap: () => _showCardModePicker(themeProvider, loc),
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
                            Flexible(
                              child: Text(
                                _cardMode == 'credit'
                                    ? loc.t('credit')
                                    : loc.t('debit'),
                                style: TextStyle(
                                  color: themeProvider.textColor,
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(Icons.keyboard_arrow_up,
                                color: Color(0xFF78BF32), size: 20),
                          ],
                        ),
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
                            Flexible(
                              child: Text(
                                _documentType,
                                style: TextStyle(
                                  color: themeProvider.textColor,
                                  fontSize:
                                      _documentType == 'Pasaporte' ? 10 : 16,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
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
                          errorStyle: TextStyle(
                            fontSize: 10,
                            color: Colors.red,
                          ),
                          errorMaxLines: 2,
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
                    onChanged: widget.isFirstCard
                        ? null // Deshabilitado si es la primera tarjeta
                        : (value) {
                            setState(() {
                              _isDefault = value!;
                            });
                          },
                    title: Text(
                      loc.t('favorite_card'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: themeProvider.textColor,
                      ),
                    ),
                    subtitle: Text(
                      widget.isFirstCard
                          ? loc.t('first_card_favorite_description')
                          : loc.t('favorite_card_description'),
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
                              final cardHolder =
                                  _cardHolderController.text.trim();

                              final card = CreditCard(
                                id: DateTime.now()
                                    .millisecondsSinceEpoch
                                    .toString(),
                                cardNumber: _formatCardNumber(cardNumber),
                                cardHolder: cardHolder,
                                expiryDate: expiryDate,
                                // CVV no se almacena por seguridad
                                isDefault: _isDefault,
                                cardType: _getCardType(cardNumber),
                                documentType: _documentType,
                                documentNumber: _documentController.text,
                                cardMode: _cardMode,
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
    final cleaned = number.replaceAll(RegExp(r'\s+'), '');
    if (cleaned.isEmpty) return CardType.unknown;

    // Visa: empieza con 4
    if (cleaned.startsWith('4')) {
      return CardType.visa;
    }
    // Mastercard: empieza con 51-55 o 2221-2720
    if (RegExp(r'^5[1-5]').hasMatch(cleaned)) {
      return CardType.mastercard;
    }
    if (cleaned.length >= 4 && cleaned.startsWith('2')) {
      final firstFour = int.tryParse(cleaned.substring(0, 4));
      if (firstFour != null && firstFour >= 2221 && firstFour <= 2720) {
        return CardType.mastercard;
      }
    }
    // American Express: empieza con 34 o 37
    if (cleaned.startsWith('34') || cleaned.startsWith('37')) {
      return CardType.amex;
    }
    // Discover: empieza con 6011, 644-649, o 65
    if (cleaned.startsWith('6011') || cleaned.startsWith('65')) {
      return CardType.discover;
    }
    if (cleaned.startsWith('64') && cleaned.length >= 3) {
      final thirdDigit = int.tryParse(cleaned.substring(2, 3));
      if (thirdDigit != null && thirdDigit >= 4 && thirdDigit <= 9) {
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
}

class _CreditCardWidget extends StatefulWidget {
  final CreditCard card;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onFavoriteTap;
  final VoidCallback? onDeleteTap;

  const _CreditCardWidget({
    required this.card,
    this.isSelected = false,
    required this.onTap,
    this.onLongPress,
    this.onFavoriteTap,
    this.onDeleteTap,
  });

  @override
  State<_CreditCardWidget> createState() => _CreditCardWidgetState();
}

class _CreditCardWidgetState extends State<_CreditCardWidget> {
  bool _isFlipped = false;

  // Obtener colores según el tipo de tarjeta
  List<Color> _getCardColors(CardType cardType) {
    switch (cardType) {
      case CardType.visa:
        return [
          const Color(0xFF1A1F71),
          const Color(0xFF0D47A1)
        ]; // Azul oscuro Visa
      case CardType.mastercard:
        return [
          const Color(0xFFEB001B),
          const Color(0xFFF79E1B)
        ]; // Rojo/Naranja Mastercard
      case CardType.amex:
        return [
          const Color(0xFF006FCF),
          const Color(0xFF00AEFF)
        ]; // Azul American Express
      case CardType.discover:
        return [
          const Color(0xFFFFB300),
          const Color(0xFFFFD54F)
        ]; // Amarillo Discover
      case CardType.diners:
        return [
          const Color(0xFF0079BE),
          const Color(0xFF004B87)
        ]; // Azul Diners Club
      case CardType.jcb:
        return [const Color(0xFF00875A), const Color(0xFF00B4D8)]; // Verde JCB
      case CardType.unionpay:
        return [
          const Color(0xFFE21836),
          const Color(0xFF00447C)
        ]; // Rojo/Azul UnionPay
      case CardType.unknown:
      default:
        return [
          const Color(0xFF6B7280),
          const Color(0xFF374151)
        ]; // Gris para desconocida
    }
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

  void _flipCard() {
    setState(() {
      _isFlipped = !_isFlipped;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final loc = AppLocalizations.of(context)!;

    return _buildFrontCard(themeProvider, loc);
  }

  // Construir el frente de la tarjeta
  Widget _buildFrontCard(ThemeProvider themeProvider, AppLocalizations loc) {
    final cardColors = _getCardColors(widget.card.cardType);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: cardColors,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            key: const ValueKey('front'),
            height: 200,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SizedBox(
                  height: 35,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Botones de estrella y basura (solo si está seleccionada o es favorita)
                      if (widget.isSelected || widget.card.isDefault)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Botón de estrella
                            // Si es favorita, mostrar estrella dorada
                            if (widget.card.isDefault)
                              const Icon(
                                Icons.star,
                                color: Color(0xFFFFD700),
                                size: 24,
                              ),
                            // Si NO es favorita pero está seleccionada, mostrar estrella vacía
                            if (!widget.card.isDefault && widget.isSelected)
                              GestureDetector(
                                onTap: widget.onFavoriteTap,
                                behavior: HitTestBehavior.translucent,
                                child: const Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Icon(
                                    Icons.star_border,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                              ),
                            const SizedBox(width: 8),
                            // Botón de basura (si está seleccionada, sea favorita o no)
                            if (widget.isSelected)
                              GestureDetector(
                                onTap: widget.onDeleteTap,
                                behavior: HitTestBehavior.translucent,
                                child: const Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Icon(
                                    Icons.delete_outline,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                              ),
                          ],
                        )
                      else
                        const SizedBox.shrink(),
                      // Logo de la tarjeta y tipo (crédito/débito)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Badge de crédito/débito
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              widget.card.cardMode == 'credit'
                                  ? loc.t('credit')
                                  : loc.t('debit'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Logo de la tarjeta
                          if (_getCardLogoPath(widget.card.cardType) != null)
                            Container(
                              height: 30,
                              width: 50,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Image.asset(
                                _getCardLogoPath(widget.card.cardType)!,
                                fit: BoxFit.contain,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      widget.card.cardNumber,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                        fontFamily: 'Courier',
                      ),
                    ),
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
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
                            alignment: Alignment.centerLeft,
                            child: Text(
                              widget.card.cardHolder.length > 20
                                  ? widget.card.cardHolder
                                      .toUpperCase()
                                      .substring(0, 20)
                                  : widget.card.cardHolder.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Column(
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
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
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
}

class CreditCard {
  final String id;
  String cardNumber;
  String cardHolder;
  String expiryDate;
  // NOTA: El CVV no se almacena por seguridad (PCI-DSS). Se solicita solo al momento de pagar.
  bool isDefault;
  final CardType cardType;
  String documentType;
  String documentNumber;
  String createdAt;
  String cardMode; // 'credit' o 'debit'

  CreditCard({
    required this.id,
    required this.cardNumber,
    required this.cardHolder,
    required this.expiryDate,
    required this.isDefault,
    required this.cardType,
    this.documentType = 'C.C',
    this.documentNumber = '',
    this.createdAt = '',
    this.cardMode = 'credit',
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

class _TrimLeftFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    // Eliminar espacios al principio
    final trimmedText = newValue.text.trimLeft();

    // Si el texto trimado es diferente, actualizar
    if (trimmedText != newValue.text) {
      return TextEditingValue(
        text: trimmedText,
        selection: TextSelection.collapsed(offset: trimmedText.length),
        composing: TextRange.empty,
      );
    }

    return newValue;
  }
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    // Convertir a mayúsculas
    final upperCaseText = newValue.text.toUpperCase();

    // Si el texto es diferente, actualizar
    if (upperCaseText != newValue.text) {
      return TextEditingValue(
        text: upperCaseText,
        selection: TextSelection.collapsed(offset: upperCaseText.length),
        composing: TextRange.empty,
      );
    }

    return newValue;
  }
}

// Widget animado para entrada y salida de tarjetas
class _AnimatedCard extends StatefulWidget {
  final Widget child;
  final bool isExiting;
  final bool isEntering;

  const _AnimatedCard({
    super.key,
    required this.child,
    this.isExiting = false,
    this.isEntering = false,
  });

  @override
  State<_AnimatedCard> createState() => _AnimatedCardState();
}

class _AnimatedCardState extends State<_AnimatedCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // Si está entrando, iniciar desde la derecha
    if (widget.isEntering) {
      _slideAnimation = Tween<Offset>(
        begin: const Offset(1.5, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ));
      _controller.forward();
    } else {
      _slideAnimation = Tween<Offset>(
        begin: Offset.zero,
        end: Offset.zero,
      ).animate(_controller);
    }

    _fadeAnimation = Tween<double>(
      begin: 1.0,
      end: 1.0,
    ).animate(_controller);
  }

  @override
  void didUpdateWidget(_AnimatedCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Si cambió el estado de salida
    if (widget.isExiting && !oldWidget.isExiting) {
      _slideAnimation = Tween<Offset>(
        begin: Offset.zero,
        end: const Offset(-1.5, 0),
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: Curves.easeIn,
      ));
      _fadeAnimation = Tween<double>(
        begin: 1.0,
        end: 0.0,
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: Curves.easeIn,
      ));
      _controller.forward(from: 0);
    }

    // Si cambió el estado de entrada
    if (widget.isEntering && !oldWidget.isEntering) {
      _slideAnimation = Tween<Offset>(
        begin: const Offset(1.5, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ));
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
