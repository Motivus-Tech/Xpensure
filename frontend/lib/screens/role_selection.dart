import 'package:flutter/material.dart';
import 'employee_signin.dart';

class RoleSelection extends StatelessWidget {
  const RoleSelection({super.key});

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF1A237E), // Deep Indigo
              Color(0xFF26A69A), // Greener Teal
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 40),
              const Text(
                "XPENSURE",
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Smart Expense Management",
                style: TextStyle(fontSize: 16, color: Colors.white70),
              ),
              const SizedBox(height: 50),
              Expanded(
                child: Center(
                  child: isWide
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _AnimatedRoleCard(
                              icon: Icons.admin_panel_settings,
                              title: "Admin",
                              description: "Manage approvals & reports",
                              color: Colors.blueAccent,
                              onTap: () {},
                            ),
                            const SizedBox(width: 40),
                            _AnimatedRoleCard(
                              icon: Icons.work_outline,
                              title: "Employee",
                              description: "Submit & track expenses",
                              color: Colors.teal,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const EmployeeSignIn(),
                                  ),
                                );
                              },
                            ),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _AnimatedRoleCard(
                              icon: Icons.admin_panel_settings,
                              title: "Admin",
                              description: "Manage approvals & reports",
                              color: Colors.blueAccent,
                              onTap: () {},
                            ),
                            const SizedBox(height: 20),
                            _AnimatedRoleCard(
                              icon: Icons.work_outline,
                              title: "Employee",
                              description: "Submit & track expenses",
                              color: Colors.teal,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const EmployeeSignIn(),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(12.0),
                child: Text(
                  "Powered by Motivus • v1.0.0",
                  style: TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimatedRoleCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final VoidCallback onTap;

  const _AnimatedRoleCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.onTap,
  });

  @override
  State<_AnimatedRoleCard> createState() => _AnimatedRoleCardState();
}

class _AnimatedRoleCardState extends State<_AnimatedRoleCard> {
  double _scale = 1.0;

  void _onTapDown(TapDownDetails details) => setState(() => _scale = 0.97);
  void _onTapUp(TapUpDetails details) {
    setState(() => _scale = 1.0);
    widget.onTap();
  }

  void _onTapCancel() => setState(() => _scale = 1.0);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: 260,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 35,
                backgroundColor: widget.color.withOpacity(0.15),
                child: Icon(widget.icon, size: 38, color: widget.color),
              ),
              const SizedBox(height: 15),
              Text(
                widget.title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: widget.color,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.description,
                style: const TextStyle(fontSize: 14, color: Colors.black54),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
