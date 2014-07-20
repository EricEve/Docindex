#charset "us-ascii"

/*
 *   Copyright (c) 1999, 2002 by Michael J. Roberts.  Permission is
 *   granted to anyone to copy and use this file for any purpose.  
 *   
 *   This is a starter T3 source file.  This is designed for a project
 *   that doesn't require any of the standard TADS 3 adventure game
 *   libraries.
 *   
 *   To compile this game in TADS Workbench, open the "Build" menu and
 *   select "Compile for Debugging."  To run the game, after compiling it,
 *   open the "Debug" menu and select "Go."
 *   
 *   This starter file is intended for people who want to use T3 to create
 *   projects that don't fall into the usual TADS 3 adventure game
 *   patterns, so it doesn't include any of the standard libraries.  If
 *   you want to create a more typical Interactive Fiction project, you
 *   might want to create a new project, and select the "introductory" or
 *   "advanced" option when the New Project Wizard asks you what kind of
 *   starter game you'd like to create.  
 */

#include <tads.h>
#include <file.h>

#define gFile globals.currentFile
#define gAnchor globals.currentAnchor
#define gEntries globals.entries
#define gHeading globals.heading
#define gMainHeading globals.mainHeading
#define gExtension globals.extension

/*
 *   The main entrypoint - the T3 virtual machine calls this function to
 *   start the program running.  'args' is a list of strings giving the
 *   command-line arguments that the user specified, if any. 
 */
main(args)
{
    parseFiles();
    
    writeIndex();
    
    "All done!\b";
}


parseFiles()
{
    local dir = FileName.fromUniversal('docs/manual');
    
//    local dir = new FileName('manual');
//    local dir = new FileName(dirPath);
    
    local files = dir.listDir().subset({f: f.getBaseName().endsWith('htm')});
    
    files = files.subset(
        {f: globals.excludedFiles.indexOf(f.getBaseName()) == nil
                                   });
    
    for(local f in files)
        parseFile(f);
    
    /* Then index the extension documentation */
    gExtension = true;    
    
    dir = FileName.fromUniversal('extensions/docs');
    
    files = dir.listDir().subset({f: f.getBaseName().endsWith('htm')});
    
    for(local f in files)
        parseFile(f);
    
        
}

parseFile(sourceFile)
{
    gFile = sourceFile.getBaseName();
    gAnchor = nil;
    
    "Parsing <<gFile>> \n";
      
    local f = File.openTextFile(sourceFile, FileAccessRead);    
    local str;
    local codeSample = nil;
    
    
    do
    {
        str = f.readFile();
        
        if(str != nil)
        {
            if(str.find('<div class="code">') 
               || str.find('<div class="cmdline">'))
                codeSample = true;
            
            if(codeSample && str.find('</div>'))
                codeSample = nil;
            
            if(!codeSample)
                parseLine(str);
            
        }
        
    } while(str != nil);
    
    codeSample = nil;
    f.closeFile();
}
    
    
parseLine(str)
{
    /* 
     *   First look for a new anchor name; if we find one it becomes the current
     *   anchor name.
     */
    local idx = str.find('<a name');
    
    while(idx)
    {
        local idx2 = str.find('>', idx);
        local idx3 = str.find('=', idx);
        local anc = str.substr(idx3 + 1, idx2 - idx3 - 1);
        anc = anc.findReplace('"', '', ReplaceAll).trim();
        anc = anc.findReplace('\'','', ReplaceAll);
        gAnchor = anc;     
        
        /* if the anchor ends in idx, it's something we want to index */
        
        if(anc.endsWith('idx'))
        {
            local idx4 = str.find('</a>', idx2);
            if(idx4)
            {
                local ename = str.substr(idx2 + 1, idx4 - idx2 - 1);               
                         
               
                /* 
                 *   If our ename starts with < we probably enclose another tag,
                 *   which will be indexed below, so we shan't create a
                 *   duplicate entry here. Otherwise, create an index entry for
                 *   the tag. Likewise if we're immediately preceding by an
                 *   opening heading tag, then this entry will be indexed by
                 *   that tag, so we won't crete a duplicat entry here.
                 *
                 */
                if(!ename.startsWith('<')
                   && !(idx > 4 && str.substr(idx - 4, 2) == '<h')) 
                    gEntries.append(new IndexEntry(ename, gFile, anc, gHeading));
            }
            
        }
        
        idx = str.find('<a name', idx2);
    }
    
    
    /* 
     *   For each of the tags we're interested in, go through the current line
     *   searching for the tags and create a new IndexEntry for each one found.
     */
    for(local tag in ['h1', 'h2', 'h3', 'h4', 'h5', 'b', 'strong'])
    {
        local openTag = '<' + tag + '>';
        local closeTag = '</' + tag + '>';
        local idx2;
        
        
        /* 
         *   A line may contain more than one tag of any particular kind, so
         *   once we've processed one, we need to keep on looking for the next
         */
        
        idx = str.find(openTag);
        
        while(idx)
        {           
            
            idx2 = str.find(closeTag, idx);
            
            /* 
             *   If the closing tag is missing, we can't meaningfully continue
             *   to process this kind of tag.
             */
            if(idx2 == nil)
                break;
            
            local ename = str.substr(idx + openTag.length, idx2 - idx -
                                     openTag.length);
            
            /* 
             *   Reset our starting idx to ensure we find a different tag next
             *   time round.
             */
            idx = idx2;
            
            /* 
             *   If one HTML tag encloses another, we want to strip the enclosed
             *   tag away from the index entry name
             */            
            ename = deNest(ename);
            
            
            /* Note the most recent heading */
            local heading = gHeading;
            
            /* 
             *   If we're processing a top-level heading, note that this is the
             *   most recent main heading.
             */
            if(tag == 'h1')
                gMainHeading = ename;
            
            if(openTag.startsWith('<h'))
            {
                /* 
                 *   If we're a heading tag, note that our name is the most
                 *   recent heading name.
                 */
                gHeading = ename;
                
                /*  
                 *   And then use the most recent main heading (<h1>) name do
                 *   describe the heading we're under.
                 */
                heading = gMainHeading;
            }
            
            if(!ename.startsWith('&gt;') && !ename.startsWith('/'))
                gEntries.append(new IndexEntry(ename, gFile, gAnchor, heading));
                        
            
            idx = str.find(openTag, idx);
        }        
        
    }
    
}

/* 
 *   Remove a nested tag sequence from a name included in another tag sequence.
 *
 *   If one HTML tag encloses another, we want to strip the enclosed tag away
 *   from the index entry name
 */
deNest(ename)
{
    if(ename.startsWith('<'))
    {
        local idx2 = ename.find('>');
        ename = ename.substr(idx2 + 1);
        idx2 = ename.find('<');
        if(idx2)
            ename = ename.substr(1, idx2 - 1);       
        
    }
    return ename;
}


class IndexEntry: object
    fileName = nil
    anchor = nil
    name = nil
    entryStr = nil
    heading = nil
    sortName = ''
    
    construct(name_, file_, anchor_, heading_)
    {       
        local extensionName = '';
        name = name_.trim();
        fileName = file_;
        if(gExtension)
        {
            fileName = '../../extensions/docs/' + fileName;
            extensionName = ' <i>[' + file_.findReplace('.htm','') + ' extension]</i>';
        }
        
        
        anchor = anchor_;
        heading = heading_.trim();
        
        local isMainHeading = (name == heading);
        
        /* 
         *   Strip the definine article off the front of the name for the
         *   purposes of sorting and listing
         */
        if(name.toLower.startsWith('the '))
        {
            name = name.substr(5);                
        }
        
        entryStr = '<a href = "' + fileName;
        
        if(anchor)
            entryStr += ('#' + anchor);
        
        entryStr += ('">' + name + '</a>');
        
        sortName = name;
        
        if(!isMainHeading)
        {
            entryStr += (' (' + heading + ')');                
            sortName += heading;
        }
        
        entryStr += extensionName;       
        
    }

    
;
 
writeIndex()
{
    gEntries.sort(SortAsc, {a, b: a.sortName.toLower > b.sortName.toLower ? 1 : -1} );    
    
    local lastName = nil;
    local lastEntry = nil;
    local fspec = new FileName('docs/manual', 'manual_idx.html');
    
    local f = File.openTextFile(fspec, FileAccessWrite);
    
    "Writing manual_idx.html\n";
    
    /* Write the HTML file header */
    f.writeFile('<html>');
    f.writeFile('<head>');
    f.writeFile('<title>Index</title>');
    f.writeFile('<link rel="stylesheet" href="sysman.css" type="text/css">');
    f.writeFile('</head>');
    f.writeFile('<body>');
    
    f.writeFile('<div class="topbar"><img src="topbar.jpg" border=0></div>');
    f.writeFile('<div class="nav"><a class="nav" href="toc.htm">Table of
        Contents</a> | ');
    f.writeFile('<a class="nav" href="final.htm">Final Moves</a> &gt; Index');
    f.writeFile('<br><span class="navnp"><a class="nav" href="changelog.htm"><i>Prev:</i> 
        Change Log</a></span>');

    f.writeFile('</div>');
    f.writeFile('<div class="main">');
    f.writeFile('<h1>Adv3Lite Manual Index</h1>');
    
    f.writeFile('<p>');
    
    /* 
     *   First write an index to the index; in other words, go through each
     *   entry, noting where the first letter of the name changes. Where it
     *   changes, create a hyperlinked reference to the initial letter.
     */
    
    for(local e in gEntries)
    {
        if(lastName == nil 
           || lastName.substr(1, 1).toLower != e.name.substr(1, 1).toLower)
        {
            local initial = e.name.substr(1, 1).toUpper();
            if(initial == '&')
                initial = '&lt;';
            
            f.writeFile('<a href="#' + initial + '">' + initial + '</a> ');
            
            lastName = e.name;
        }
    }
    
    f.writeFile('<p>');
    
    for(local e in gEntries)
    {
        if(lastName == nil 
           || lastName.substr(1, 1).toLower != e.name.substr(1, 1).toLower)
        {
            f.writeFile('<p>');
            local initial = e.name.substr(1, 1).toUpper();
            if(initial == '&')
                initial = '&lt;';
            
                
            f.writeFile('<a name="' + initial + '"><h2>' + initial +
                        '</h2></a>' );
        }
        
        /* Avoid writing duplicate entries */
        if(e.entryStr != lastEntry)
        {              
            f.writeFile(e.entryStr + '<br>');
            lastEntry = e.entryStr;
        }
        lastName = e.name;
    }
    
    
    /* Write the HTML file footer */
    f.writeFile('</div>');
    f.writeFile('<hr class="navb"><div class="navb">');
    f.writeFile('<i>adv3Lite Library Manual</i><br>');
    f.writeFile('<a class="nav" href="toc.htm">Table of
        Contents</a> | ');
    f.writeFile('<a class="nav" href="final.htm">Final Moves</a> &gt; Index');
    f.writeFile('<br><span class="navnp"><a class="nav" href="changelog.htm"><i>Prev:</i> 
        Change Log</a></span>');

    f.writeFile('</div>');
    f.writeFile('</body>');
    f.writeFile('</html>');
    
    /* Close the file */
    f.closeFile();
}



globals: object
    
    /* List of files that should not be indexed or are not worth indexing */
    excludedFiles = [
        'changelog.htm',
        'action.htm',
        'actor.htm',
        'conclusion.htm',
        'feedback.htm',
        'index.htm',
        'toc.htm',
        'source.htm',
        'docs-intro.htm',
        'actionref.htm',
        'begin.htm',
        'core.htm',
        'optional.htm'
    ]    
    
    /* The file currently being processed */
    currentFile = nil
    
    /* The most recently encountered anchor name */
    currentAnchor = nil
    
    /* Vector containing the index entries discovered */
    entries = static new Vector(100)
    
    /* The last heading encountered */
    heading = nil
    
    /* The last main heading (<h1>) encountered */
    mainHeading = nil
    
    /* Are we indexing an extension file? */
    extension = nil
;

modify String
    trim()
    {
        local s = self;
        while(s.substr(1, 1) == ' ')
            s = s.substr(2);
        
        while(s.substr(-1, 1) == ' ')
            s = s.substr(1, s.length - 1);
        
        return s;
    }
;
