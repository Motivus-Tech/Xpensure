import 'package:flutter/material.dart';
import 'employee_signin.dart';
import 'admin_signin.dart';
import 'approver_signin.dart';

class RoleSelection extends StatelessWidget {
  const RoleSelection({super.key});

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1A237E), Color(0xFF009688)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 20),

                // App Title
                const Text(
                  "XPENSURE",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Smart Expense Management",
                  style: TextStyle(fontSize: 16, color: Colors.white70),
                ),
                const SizedBox(height: 30),

                // Role Cards
                Center(
                  child: isWide
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _AnimatedRoleCard(
                              icon: Icons.admin_panel_settings,
                              title: "Admin",
                              description: "Manage HR tasks",
                              color: Colors.blueAccent,
                              width: 220,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const AdminSignInPage()),
                                );
                              },
                            ),
                            const SizedBox(width: 20),
                            _AnimatedRoleCard(
                              icon: Icons.business_center,
                              title: "Approver",
                              description: "Review & approve expenses",
                              color: const Color.fromARGB(255, 100, 187, 234),
                              width: 220,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const ApproverSignInPage()),
                                );
                              },
                            ),
                            const SizedBox(width: 20),
                            _AnimatedRoleCard(
                              icon: Icons.work_outline,
                              title: "Employee",
                              description: "Submit & track expenses",
                              color: Colors.teal,
                              width: 220,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const EmployeeSignInPage()),
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
                              description: "Manage HR tasks",
                              color: Colors.blueAccent,
                              width: 260,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const AdminSignInPage()),
                                );
                              },
                            ),
                            const SizedBox(height: 15),
                            _AnimatedRoleCard(
                              icon: Icons.business_center,
                              title: "Approver",
                              description: "Review & approve expenses",
                              color: const Color.fromARGB(255, 100, 187, 234),
                              width: 260,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const ApproverSignInPage()),
                                );
                              },
                            ),
                            const SizedBox(height: 15),
                            _AnimatedRoleCard(
                              icon: Icons.work_outline,
                              title: "Employee",
                              description: "Submit & track expenses",
                              color: Colors.teal,
                              width: 260,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const EmployeeSignInPage()),
                                );
                              },
                            ),
                          ],
                        ),
                ),

                const SizedBox(height: 20),

                // Footer - Moved outside of the main content area
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  child: const Text(
                    "Powered by Motivus • v1.0.0",
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
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
  final double width;
  final VoidCallback onTap;

  const _AnimatedRoleCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.width,
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
      behavior: HitTestBehavior.translucent,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: widget.width,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(0.4),
                blurRadius: 10,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: widget.color.withOpacity(0.15),
                child: Icon(widget.icon, size: 36, color: widget.color),
              ),
              const SizedBox(height: 12),
              Text(
                widget.title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: widget.color,
                ),
              ),
              const SizedBox(height: 6),
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
