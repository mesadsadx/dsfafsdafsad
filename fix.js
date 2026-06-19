const fs = require('fs');
const path = require('path');

function walk(dir) {
    let results = [];
    const list = fs.readdirSync(dir);
    list.forEach(function(file) {
        let filePath = path.join(dir, file);
        const stat = fs.statSync(filePath);
        if (stat && stat.isDirectory()) { 
            results = results.concat(walk(filePath));
        } else { 
            if (filePath.endsWith('.dart')) results.push(filePath);
        }
    });
    return results;
}

const files = walk('lib');
files.forEach(f => {
    let content = fs.readFileSync(f, 'utf8');
    let newContent = content.replace(/\.withOpacity\(([^()]+)\)/g, '.withValues(alpha: $1)');
    if (newContent !== content) {
        fs.writeFileSync(f, newContent, 'utf8');
        console.log('Fixed', f);
    }
});
