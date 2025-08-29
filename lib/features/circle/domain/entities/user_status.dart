// lib/features/circle/domain/entities/user_status.dart

enum UserStatus {
  // El emoji es el valor que se guardará en la base de datos y se mostrará en la UI
  fine("😊", "Bien"),
  worried("😰", "Preocupado"),
  location("📍", "Ubicación"),
  sos("🆘", "SOS"),
  thinking("❤️", "Pensando en ti");

  const UserStatus(this.emoji, this.description);
  final String emoji;
  final String description;
}