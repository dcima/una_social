// una_chat_main_screen.dart

import 'package:flutter/material.dart';
import 'package:una_chat/screens/new_chat.dart';
import 'package:una_social/helpers/logger_helper.dart';
import 'package:una_social/helpers/snackbar_helper.dart'; // Importa il logger

// Modello semplice per i dati di una chat (invariato)
class ChatItemModel {
  final String avatarUrl; // o AssetImage per asset locali
  final String name;
  final String lastMessage;
  final String time;
  final int unreadCount;
  final bool isMuted;
  final bool isPinned;
  final bool isGroup;
  final String? lastMessageSender; // Per i gruppi

  ChatItemModel({
    required this.avatarUrl,
    required this.name,
    required this.lastMessage,
    required this.time,
    this.unreadCount = 0,
    this.isMuted = false,
    this.isPinned = false,
    this.isGroup = false,
    this.lastMessageSender,
  });
}

class UnaChatMainScreen extends StatefulWidget {
  const UnaChatMainScreen({super.key});

  @override
  State<UnaChatMainScreen> createState() => _UnaChatMainScreenState();
}

class _UnaChatMainScreenState extends State<UnaChatMainScreen> {
  int _bottomNavIndex = 0; // Per la BottomNavigationBar

  // Dati di esempio (invariati)
  final List<ChatItemModel> _chatItems = [];
  final List<ChatItemModel> chatItems = [
    ChatItemModel(
      avatarUrl: 'https://placehold.co/32x32',
      name: 'Blocco Note (tu)',
      lastMessage: '✓ https://www.facebook.com...',
      time: 'Ieri',
      isPinned: true,
    ),
    ChatItemModel(
      avatarUrl: 'https://placehold.co/32x32',
      name: 'A35-Accademia Capital O...',
      lastMessage: 'Stefano Fontana: Questo...',
      time: '11:58',
      unreadCount: 4,
      isMuted: true,
      isGroup: true,
      lastMessageSender: 'Stefano Fontana',
    ),
    ChatItemModel(
      avatarUrl: 'group_avatar',
      name: 'Regalo Fiorella',
      lastMessage: 'Morena: Stasera faccio il pu...',
      time: '11:56',
      unreadCount: 1,
      isGroup: true,
      lastMessageSender: 'Morena',
    ),
    ChatItemModel(
      avatarUrl: 'https://via.placeholder.com/150/f66b97',
      name: 'Gli Svalvolati',
      lastMessage: 'Parà: Buongiorno✌️',
      time: '11:46',
      unreadCount: 1,
      isMuted: true,
      isGroup: true,
      lastMessageSender: 'Parà',
    ),
    ChatItemModel(
      avatarUrl: 'https://via.placeholder.com/150/56a8c2',
      name: '5A Majorana',
      lastMessage: 'cristina martelli68: Noi nn v...',
      time: '11:33',
      unreadCount: 99,
      isGroup: true,
      lastMessageSender: 'cristina martelli68',
    ),
    ChatItemModel(
      avatarUrl: 'https://via.placeholder.com/150/b0f7cc',
      name: 'Sorina Popa',
      lastMessage: '✓ 💋💋💋 LIFE SAVER!!!',
      time: '11:30',
    ),
  ];

  String _selectedFilter = "Tutti";

  Widget cercaInChat(String value, BuildContext context) {
    appLogger.info('Cerca in chat: $value');
    SnackbarHelper.showInfoSnackbar(context, "Funzione di ricerca non implementata");
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    // MODIFICA: Otteniamo il tema corrente per accedere ai suoi colori e stili
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Logica di filtraggio (invariata)
    List<ChatItemModel> filteredItems = _chatItems;
    if (_selectedFilter == "Gruppi") {
      filteredItems = _chatItems.where((item) => item.isGroup).toList();
    } else if (_selectedFilter == "Preferiti") {
      filteredItems = _chatItems.where((item) => item.isPinned).toList();
    }

    return Scaffold(
      // MODIFICA: lo scaffold usa il suo colore di sfondo dal tema
      // backgroundColor: Colors.black87, <-- Rimosso
      body: Column(
        children: [
          Row(
            children: [
              // Barra di ricerca
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                  child: TextField(
                    // MODIFICA: La decorazione ora è definita nel tema globale (main.dart)
                    // ma possiamo ancora personalizzare se necessario.
                    onChanged: (String value) {
                      // Controlla se la lunghezza del testo è di almeno 3 caratteri
                      if (value.length >= 3) {
                        cercaInChat(value, context); // MODIFICA: Usa il logger per registrare l'input di ricerca
                        // log() da 'dart:developer' è preferibile a print() per un output più pulito.
                      }
                    },
                    decoration: InputDecoration(
                      hintText: 'Cerca',
                      hintStyle: TextStyle(color: theme.hintColor),
                      prefixIcon: Icon(Icons.search, color: theme.hintColor),
                      fillColor: colorScheme.surfaceContainerHighest, // Usa un colore di sfondo dal tema
                      contentPadding: const EdgeInsets.symmetric(vertical: 0.0),
                    ),
                    style: TextStyle(color: colorScheme.onSurface), // Colore testo dal tema
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                child: IconButton(
                  icon: Icon(Icons.edit, color: theme.hintColor),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true, // Permette al sheet di occupare tutto lo schermo
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
                      ),
                      builder: (context) {
                        // Occupa il 95% dell'altezza dello schermo per un look più nativo
                        return SizedBox(
                          height: MediaQuery.of(context).size.height * 0.95,
                          child: const NewChatScreen(),
                        );
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                child: IconButton(
                  icon: Icon(Icons.filter_alt, color: theme.hintColor),
                  onPressed: () {
                    SnackbarHelper.showInfoSnackbar(context, "Impostazioni filter non implementate");
                  },
                ),
              ),
            ],
          ),
          // Filtri
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip("Tutti", Icons.chat_bubble_outline),
                  _buildFilterChip("Preferiti", Icons.star_border_outlined),
                  _buildFilterChip("Gruppi", Icons.group_outlined),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: ActionChip(
                      // MODIFICA: Usa i colori del tema
                      avatar: Icon(Icons.add, size: 18, color: theme.chipTheme.iconTheme?.color),
                      label: const Text(''),
                      backgroundColor: theme.chipTheme.backgroundColor,
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.all(6),
                      onPressed: () {
                        SnackbarHelper.showInfoSnackbar(context, "Adesso ci penso ....");
                      },
                    ),
                  )
                ],
              ),
            ),
          ),
          // Lista delle chat
          Expanded(
            child: ListView.builder(
              itemCount: filteredItems.length,
              itemBuilder: (context, index) {
                final item = filteredItems[index];
                return _buildChatItem(item);
              },
            ),
          ),
        ],
      ),
      // MODIFICA: Il FAB ora usa lo stile definito nel tema
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.message_outlined),
      ),
      // MODIFICA: La BottomNav ora usa lo stile definito nel tema
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _bottomNavIndex,
        onTap: (index) {
          setState(() {
            _bottomNavIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: const TextStyle(fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
        items: [
          BottomNavigationBarItem(
            icon: Badge(
              label: Text(_chatItems.where((c) => c.unreadCount > 0).fold<int>(0, (prev, e) => prev + e.unreadCount).toString()),
              isLabelVisible: _chatItems.any((c) => c.unreadCount > 0),
              child: const Icon(Icons.chat_bubble),
            ),
            label: 'Chat',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.camera_enhance_outlined),
            label: 'Aggiorname...',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.groups_outlined),
            label: 'Community',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.call_outlined),
            label: 'Chiamate',
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, IconData icon) {
    // MODIFICA: Otteniamo il tema anche qui
    final theme = Theme.of(context);
    final chipTheme = theme.chipTheme;
    final bool isSelected = _selectedFilter == label.split(" ")[0];

    // MODIFICA: Usiamo i colori e stili del ChipTheme definito in main.dart
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: FilterChip(
        avatar: Icon(
          icon,
          size: 18,
          color: isSelected ? chipTheme.secondaryLabelStyle?.color : chipTheme.iconTheme?.color,
        ),
        label: Text(label, style: isSelected ? chipTheme.secondaryLabelStyle : chipTheme.labelStyle),
        selected: isSelected,
        onSelected: (bool selected) {
          if (selected) {
            setState(() {
              _selectedFilter = label.split(" ")[0];
            });
          }
        },
        backgroundColor: chipTheme.backgroundColor,
        selectedColor: chipTheme.selectedColor,
        checkmarkColor: chipTheme.secondaryLabelStyle?.color,
        shape: const StadiumBorder(),
      ),
    );
  }

  Widget _buildChatItem(ChatItemModel item) {
    // MODIFICA: Otteniamo il tema per usare i colori corretti
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListTile(
      leading: CircleAvatar(
        radius: 25,
        backgroundColor: theme.cardColor, // Colore di sfondo per l'avatar dal tema
        child: item.avatarUrl == 'group_avatar'
            ? Icon(Icons.group, color: theme.hintColor, size: 30)
            : item.avatarUrl.startsWith('http')
                ? ClipOval(child: Image.network(item.avatarUrl, fit: BoxFit.cover, width: 50, height: 50))
                : ClipOval(child: Image.asset(item.avatarUrl, fit: BoxFit.cover, width: 50, height: 50)),
      ),
      title: Text(
        item.name,
        // MODIFICA: Colore del testo principale dal tema
        style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w500),
      ),
      subtitle: Row(
        children: [
          if (item.lastMessage.startsWith('✓'))
            Icon(
              Icons.done_all,
              size: 16,
              // MODIFICA: Colore spunte
              color: item.lastMessage.startsWith('✓✓') ? Colors.blueAccent : theme.hintColor,
            ),
          if (item.lastMessage.startsWith('✓')) const SizedBox(width: 4),
          Expanded(
            child: Text(
              (item.isGroup && item.lastMessageSender != null && !item.lastMessage.startsWith('✓')) ? '${item.lastMessageSender}: ${item.lastMessage.replaceFirst('✓', '').trim()}' : item.lastMessage.replaceFirst('✓', '').trim(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              // MODIFICA: Colore del testo secondario dal tema
              style: TextStyle(color: theme.hintColor),
            ),
          ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            item.time,
            style: TextStyle(
              // MODIFICA: Usa il colore primario del tema per i messaggi non letti
              color: item.unreadCount > 0 ? colorScheme.primary : theme.hintColor,
              fontSize: 12,
              fontWeight: item.unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (item.isPinned) Icon(Icons.push_pin, color: theme.hintColor, size: 16),
              if (item.isPinned && (item.isMuted || item.unreadCount > 0)) const SizedBox(width: 6),
              if (item.isMuted) Icon(Icons.notifications_off_outlined, color: theme.hintColor, size: 16),
              if (item.isMuted && item.unreadCount > 0) const SizedBox(width: 6),
              if (item.unreadCount > 0)
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: colorScheme.primary, // MODIFICA: Badge usa il colore primario
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    item.unreadCount > 99 ? '99+' : item.unreadCount.toString(),
                    // MODIFICA: Il colore del testo sul badge si adatta per il contrasto
                    style: TextStyle(color: colorScheme.onPrimary, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        ],
      ),
      onTap: () {
        logInfo('Tapped on ${item.name}');
      },
    );
  }
}
