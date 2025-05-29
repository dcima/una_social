import 'package:flutter/material.dart';
import 'package:una_social/helpers/logger_helper.dart'; // Importa il logger

// Modello semplice per i dati di una chat (da sostituire con i tuoi modelli reali)
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

  // Dati di esempio, rimpiazzali con i dati reali dalla tua logica/backend
  final List<ChatItemModel> _chatItems = [
    ChatItemModel(
      avatarUrl: 'https://via.placeholder.com/150/771796', // Esempio placeholder
      name: 'Blocco Note (tu)',
      lastMessage: '✓ https://www.facebook.com...',
      time: 'Ieri',
      isPinned: true,
    ),
    ChatItemModel(
      avatarUrl: 'https://via.placeholder.com/150/24f355', // Esempio placeholder
      name: 'A35-Accademia Capital O...',
      lastMessage: 'Stefano Fontana: Questo...',
      time: '11:58',
      unreadCount: 4,
      isMuted: true,
      isGroup: true,
      lastMessageSender: 'Stefano Fontana',
    ),
    ChatItemModel(
      avatarUrl: 'group_avatar', // Usa un placeholder per l'icona di gruppo
      name: 'Regalo Fiorella',
      lastMessage: 'Morena: Stasera faccio il pu...',
      time: '11:56',
      unreadCount: 1,
      isGroup: true,
      lastMessageSender: 'Morena',
    ),
    ChatItemModel(
      avatarUrl: 'https://via.placeholder.com/150/f66b97', // Esempio placeholder
      name: 'Gli Svalvolati',
      lastMessage: 'Parà: Buongiorno✌️',
      time: '11:46',
      unreadCount: 1,
      isMuted: true,
      isGroup: true,
      lastMessageSender: 'Parà',
    ),
    ChatItemModel(
      avatarUrl: 'https://via.placeholder.com/150/56a8c2', // Esempio placeholder
      name: '5A Majorana',
      lastMessage: 'cristina martelli68: Noi nn v...',
      time: '11:33', // Orario tagliato nell'immagine
      unreadCount: 99, // Esempio per un numero alto
      isGroup: true,
      lastMessageSender: 'cristina martelli68',
    ),
    ChatItemModel(
      avatarUrl: 'https://via.placeholder.com/150/b0f7cc', // Esempio placeholder
      name: 'Sorina Popa',
      lastMessage: '✓ 💋💋💋 LIFE SAVER!!!',
      time: '11:30', // Orario ipotetico
    ),
  ];

  String _selectedFilter = "Tutti"; // Potrebbe essere 'Preferiti', 'Gruppi', ecc.

  @override
  Widget build(BuildContext context) {
    // Filtraggio basato su _selectedFilter (molto basilare)
    List<ChatItemModel> filteredItems = _chatItems; // Inizialmente tutti
    if (_selectedFilter == "Gruppi") {
      filteredItems = _chatItems.where((item) => item.isGroup).toList();
    } else if (_selectedFilter == "Preferiti") {
      // Logica per i preferiti (es. basata su isPinned o un altro flag)
      // Per ora mostriamo i pinnati come preferiti
      filteredItems = _chatItems.where((item) => item.isPinned).toList();
    }
    // Aggiungi altri filtri se necessario

    return Scaffold(
      backgroundColor: Colors.black87, // Sfondo scuro come da screenshot
      appBar: AppBar(
        backgroundColor: Colors.grey[900], // Colore AppBar più scuro
        title: const Text(
          'WhatsApp', // O 'Una Chat' o quello che preferisci
          style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.camera_alt_outlined, color: Colors.white70),
            onPressed: () {
              // Azione fotocamera
            },
          ),
          // L'icona di ricerca è nella barra sotto l'AppBar nello screenshot
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white70),
            onPressed: () {
              // Azione menu
            },
          ),
        ],
        elevation: 0, // Come da stile WhatsApp
      ),
      body: Column(
        children: [
          // Barra di ricerca (come "Chiedi a Meta AI o cerca")
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Chiedi a Meta AI o cerca',
                hintStyle: TextStyle(color: Colors.grey[400]),
                prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                filled: true,
                fillColor: Colors.grey[800], // Colore di sfondo della barra
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30.0),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0.0),
              ),
              style: const TextStyle(color: Colors.white),
            ),
          ),
          // Filtri (Preferiti, Gruppi, Famiglia, +)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip("Tutti", Icons.chat_bubble_outline), // Aggiunto un "Tutti"
                  _buildFilterChip("Preferiti", Icons.star_border_outlined),
                  _buildFilterChip("Gruppi 4", Icons.group_outlined), // "4" è un esempio
                  _buildFilterChip("Famiglia", Icons.home_outlined), // Icona esempio
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: ActionChip(
                      avatar: const Icon(Icons.add, size: 18, color: Colors.white70),
                      label: const Text(''), // Nello screenshot è solo un +
                      backgroundColor: Colors.grey[800],
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.all(6),
                      onPressed: () {
                        // Azione per aggiungere filtro o altro
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Azione nuova chat
        },
        backgroundColor: const Color(0xFF00A884), // Verde WhatsApp
        child: const Icon(Icons.message_outlined, color: Colors.white), // Icona più simile a quella di WhatsApp
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _bottomNavIndex,
        onTap: (index) {
          setState(() {
            _bottomNavIndex = index;
          });
          // Qui puoi gestire la navigazione o il cambio di vista
        },
        type: BottomNavigationBarType.fixed, // Per vedere etichette e icone sempre
        backgroundColor: Colors.grey[900], // Sfondo della BottomNav
        selectedItemColor: Colors.white, // Colore dell'item selezionato
        unselectedItemColor: Colors.grey[600], // Colore degli item non selezionati
        selectedLabelStyle: const TextStyle(fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
        items: [
          BottomNavigationBarItem(
            icon: Badge(
              // Per mostrare il contatore notifiche sull'icona Chat
              label: Text(_chatItems.where((c) => c.unreadCount > 0).fold<int>(0, (prev, e) => prev + e.unreadCount).toString()),
              isLabelVisible: _chatItems.any((c) => c.unreadCount > 0), // Mostra solo se ci sono non letti
              child: const Icon(Icons.chat_bubble),
            ),
            label: 'Chat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.camera_enhance_outlined), // Simile all'icona "Aggiornamenti" (stato)
            label: 'Aggiorname...',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.groups_outlined),
            label: 'Community',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.call_outlined),
            label: 'Chiamate',
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, IconData icon) {
    final bool isSelected = _selectedFilter == label.split(" ")[0]; // Semplice check sul nome base
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: FilterChip(
        avatar: Icon(icon, size: 18, color: isSelected ? Colors.black87 : Colors.white70),
        label: Text(label, style: TextStyle(color: isSelected ? Colors.black87 : Colors.white70)),
        selected: isSelected,
        onSelected: (bool selected) {
          if (selected) {
            setState(() {
              _selectedFilter = label.split(" ")[0];
            });
          }
        },
        backgroundColor: Colors.grey[800],
        selectedColor: Colors.white70, // Colore del chip selezionato
        checkmarkColor: Colors.black87,
        shape: const StadiumBorder(),
      ),
    );
  }

  Widget _buildChatItem(ChatItemModel item) {
    return ListTile(
      leading: CircleAvatar(
        radius: 25,
        backgroundColor: Colors.grey[700], // Colore di sfondo per l'avatar
        // Se avatarUrl è un path locale per un'icona di gruppo:
        child: item.avatarUrl == 'group_avatar'
            ? Icon(Icons.group, color: Colors.grey[400], size: 30)
            : item.avatarUrl.startsWith('http')
                ? ClipOval(child: Image.network(item.avatarUrl, fit: BoxFit.cover, width: 50, height: 50))
                : ClipOval(child: Image.asset(item.avatarUrl, fit: BoxFit.cover, width: 50, height: 50)), // Per asset locali
      ),
      title: Text(
        item.name,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
      ),
      subtitle: Row(
        children: [
          if (item.lastMessage.startsWith('✓')) // Per le spunte blu/grigie
            Icon(
              Icons.done_all,
              size: 16,
              color: item.lastMessage.startsWith('✓✓') ? Colors.blueAccent : Colors.grey[500], // Esempio per spunte
            ),
          if (item.lastMessage.startsWith('✓')) const SizedBox(width: 4),
          Expanded(
            child: Text(
              (item.isGroup && item.lastMessageSender != null && !item.lastMessage.startsWith('✓')) ? '${item.lastMessageSender}: ${item.lastMessage.replaceFirst('✓', '').trim()}' : item.lastMessage.replaceFirst('✓', '').trim(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey[400]),
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
              color: item.unreadCount > 0 ? const Color(0xFF00A884) : Colors.grey[500],
              fontSize: 12,
              fontWeight: item.unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (item.isPinned) Icon(Icons.push_pin, color: Colors.grey[500], size: 16),
              if (item.isPinned && (item.isMuted || item.unreadCount > 0)) const SizedBox(width: 6),
              if (item.isMuted) Icon(Icons.notifications_off_outlined, color: Colors.grey[500], size: 16),
              if (item.isMuted && item.unreadCount > 0) const SizedBox(width: 6),
              if (item.unreadCount > 0)
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: const BoxDecoration(
                    color: Color(0xFF00A884), // Verde WhatsApp per il badge
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    item.unreadCount > 99 ? '99+' : item.unreadCount.toString(),
                    style: const TextStyle(color: Colors.black87, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        ],
      ),
      onTap: () {
        // Azione quando si clicca su una chat
        logInfo('Tapped on ${item.name}');
      },
    );
  }
}

// DA INSERIRE NEL TUO MAIN O DOVE DEFINISCI LE ROUTE CON GoRouter
// Esempio di come potrebbe essere usato con GoRouter nel file principale:
/*
GoRoute(
  path: '/una_chat', // Il path che hai definito
  name: 'una_chat_main_screen', // Opzionale, ma utile
  builder: (context, state) {
    // HomeScreen è un ipotetico wrapper, se non lo hai, usa direttamente UnaChatMainScreen
    // return const HomeScreen( // Se HomeScreen è uno Scaffold con AppBar generica
    //   screenName: 'Una Chat', // Passato a HomeScreen
    //   child: UnaChatMainScreen(),
    // );
    // Oppure, se UnaChatMainScreen è autonoma e gestisce il suo Scaffold e AppBar:
    return const UnaChatMainScreen();
  },
),
*/
