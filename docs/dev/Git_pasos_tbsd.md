## **TBSD**

### **Definición**

En Trunk-Based Software Development (TBSD), el objetivo es tener ramas de corta duración que se integran rápidamente al "tronco" principal (`main` o `master`). Una convención de nombres clara es muy útil.

Te sugiero usar el formato `tipo/descripcion-corta`. Para el trabajo que estamos haciendo ahora, un nombre excelente sería:

**`feat/auth-domain-layer`**

Desglose:

  * **`feat`**: nueva funcionalidad ("feature") 
  * **`fix`**: corrección de error 
  * **`chore`**: mantenimiento 
  * **`refactor`**: refactorización
    
Este formato es fácil de leer y ayuda a todo el equipo a entender rápidamente el propósito de cada rama.

---

### **Flujo**

```bash
# Si la rama actual es 'feature/ux-feedback-processing'

# 1. Subir al 'stage' todos los cambios
git status
git add .
git status

# 2. Commitear los cambios
git commit -m "..."

# 3. Copiar al repo
git push origin feature/ux-feedback-processing
```

4. <mark>Hacer el Pull Request, Merge y la eliminación de la rama remota actual, desde la plataforma [Github](https://github.com/)<mark/>

```bash
# 5. Traer toda la última versión al 'main' local
git checkout main
git pull origin main

# 6. Borrar rama actual
git branch -D feature/ux-feedback-processing

# 7. Desde el 'main' crear nueva rama
git checkout -b feature/manage-categories
```

---

