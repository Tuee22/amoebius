# Amoebius Demo Presentation

This directory contains the Marp-based presentation for Amoebius demos.

## Files

- `slides.md` - Main presentation source (Markdown with Marp syntax)
- `presentation.html` - Generated HTML presentation
- `presentation.pdf` - Generated PDF presentation
- `assets/` - Images, logos, and diagrams

## Building the Presentation

### HTML Output (recommended for live demos):
```bash
marp slides.md -o presentation.html --html
```

### PDF Output:
```bash
marp slides.md -o presentation.pdf --pdf --allow-local-files
```

### Live Server (for development):
```bash
marp -s slides.md
```

## Presentation Structure

1. **Title Slide** - Project introduction
2. **Problem Statement** - Current challenges with cloud deployments
3. **Solution Overview** - How Amoebius addresses these challenges
4. **Technology Stack** - Logos and descriptions of all components
5. **Architecture** - High-level system design
6. **Hierarchical Clusters** - Parent-child cluster relationships
7. **Security Model** - Zen of Amoebius principles
8. **Demo Flow** - Step-by-step walkthrough
9. **Benefits** - Value propositions
10. **Use Cases** - Industry applications
11. **Getting Started** - Quick start guide
12. **Q&A** - Contact and resources

## Customization

- Edit `slides.md` to modify content
- Update logos in `assets/logos/` (see README in that folder)
- Modify CSS in the `style:` section for visual changes
- Add diagrams to `assets/diagrams/` and reference them

## Tips for Presenting

- Use **F11** for fullscreen in browsers
- **Arrow keys** or **space** to navigate slides
- HTML version supports speaker notes (if added)
- PDF version good for sharing/printing