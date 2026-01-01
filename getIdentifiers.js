(async function() {
    const response = await fetch("https://eel.is/c++draft/libraryindex");
    const htmlText = await response.text();

    const parser = new DOMParser();
    const virtualDoc = parser.parseFromString(htmlText, 'text/html');

    const allAandI = virtualDoc.querySelectorAll('a, i');
    allAandI.forEach(element => {
        if (element.parentNode) {
            element.parentNode.removeChild(element);
        }
    });
    
    const textttSpans = virtualDoc.querySelectorAll('span.texttt');
    const textArray = Array.from(textttSpans).map(span => {
        return span.textContent || span.innerText || '';
    }).filter(text => text.trim() !== '');
    

    const identifierRegex = /[a-zA-Z_][a-zA-Z0-9_]*/g;
    const allIdentifiers = [];
    
    textArray.forEach(text => {
        const matches = text.match(identifierRegex);
        if (matches) {
            allIdentifiers.push(...matches);
        }
    });
    
    const uniqueIdentifiers = [...new Set(allIdentifiers)];

    const fileContent = uniqueIdentifiers.filter(str => {
        if (str.length !== 1) return true;
        const char = str.charAt(0);
        return !(char >= 'A' && char <= 'Z');
    }).join('\n');

    const blob = new Blob([fileContent], { type: 'text/plain;charset=utf-8' });
    const url = URL.createObjectURL(blob);
    
    const downloadLink = document.createElement('a');
    downloadLink.href = url;
    downloadLink.download = 'identifiers.txt';

    document.body.appendChild(downloadLink);
    downloadLink.click();
    document.body.removeChild(downloadLink);
})();
