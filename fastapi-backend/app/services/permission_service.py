ROLE_PERMISSIONS = {
    "admin": [
        "dashboard", "students", "teachers", "academics", "attendance",
        "fees", "exams", "leaves", "reports", "settings", "notifications",
        "portal", "face",
    ],
    "teacher": ["dashboard", "attendance", "academics", "leaves", "notifications"],
    "accountant": ["dashboard", "fees", "notifications"],
    "student": ["portal", "notifications"],
    "parent": ["portal", "notifications"],
}


class PermissionService:
    def for_role(self, role: str) -> list[str]:
        return ROLE_PERMISSIONS.get(role, [])

    def has(self, role: str, permission: str) -> bool:
        return permission in self.for_role(role)
