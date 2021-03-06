/*
 * The MIT License
 *
 * Copyright (c) 2009 The Broad Institute
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */
package edu.wustl.genome.samtools;

import net.sf.picard.PicardException;
import net.sf.picard.cmdline.CommandLineProgram;
import net.sf.picard.cmdline.Option;
import net.sf.picard.cmdline.StandardOptionDefinitions;
import net.sf.picard.cmdline.Usage;
import net.sf.picard.fastq.FastqRecord;
import net.sf.picard.fastq.FastqWriter;
import net.sf.picard.fastq.FastqWriterFactory;
import net.sf.picard.io.IoUtil;
import net.sf.samtools.SAMFileReader;
import net.sf.samtools.SAMReadGroupRecord;
import net.sf.samtools.SAMRecord;
import net.sf.samtools.SAMUtils;
import net.sf.samtools.util.SequenceUtil;
import net.sf.samtools.util.StringUtil;

import java.io.File;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * Extracts read sequences and qualities from the input SAM/BAM file and writes them into 
 * the output file in Sanger fastq format. 
 * See <a href="http://maq.sourceforge.net/fastq.shtml">MAQ FastQ specification</a> for details.
 * In the RC mode (default is True), if the read is aligned and the alignment is to the reverse strand on the genome,
 * the read's sequence from input sam file will be reverse-complemented prior to writing it to fastq in order restore correctly 
 * the original read sequence as it was generated by the sequencer.
 */
public class GCSamToFastq extends CommandLineProgram {
    @Usage 
    public String USAGE = "Extracts read sequences and qualities from the input SAM/BAM file and writes them into "+
        "the output file in Sanger fastq format. In the RC mode (default is True), if the read is aligned and the alignment is to the reverse strand on the genome, "+
        "the read's sequence from input SAM file will be reverse-complemented prior to writing it to fastq in order restore correctly "+
        "the original read sequence as it was generated by the sequencer.";

    @Option(doc="Input SAM/BAM file to extract reads from", shortName=StandardOptionDefinitions.INPUT_SHORT_NAME)
    public File INPUT ;

    @Option(shortName="F", doc="Output fastq file (single-end fastq or, if paired, first end of the pair fastq).", mutex={"OUTPUT_PER_RG"})
    public File FASTQ ;

    @Option(shortName="F2", doc="Output fastq file (if paired, second end of the pair fastq).", optional=true, mutex={"OUTPUT_PER_RG"})
    public File SECOND_END_FASTQ ;

    @Option(shortName="FRGF", doc="Fragment output fastq file", optional=true, mutex={"OUTPUT_PER_RG"})
    public File FRAGMENT_FASTQ;

    @Option(shortName="OPRG", doc="Output a fastq file per read group (two fastq files per read group if the group is paired).", optional=true, mutex={"FASTQ", "SECOND_END_FASTQ","FRAGMENT_FASTQ"})
    public boolean OUTPUT_PER_RG ;

    @Option(shortName="ODIR", doc="Directory in which to output the fastq file(s).  Used only when OUTPUT_PER_RG is true.", optional=true)
    public File OUTPUT_DIR;

    @Option(shortName="RC", doc="Re-reverse bases and qualities of reads with negative strand flag set before writing them to fastq", optional=true)
    public boolean RE_REVERSE = true;

    @Option(shortName="NON_PF", doc="Include non-PF reads from the SAM file into the output FASTQ files.")
    public boolean INCLUDE_NON_PF_READS = false;

    @Option(shortName="NO_ORPHAN", doc="Do not warn on orphaned mates when one side of the pair was filtered")
    public boolean IGNORE_ORPHAN_MATES = false;

    @Option(shortName="CLIP_ATTR", doc="The attribute that stores the position at which " +
            "the SAM record should be clipped", optional=true)
    public String CLIPPING_ATTRIBUTE;

    @Option(shortName="CLIP_ACT", doc="The action that should be taken with clipped reads: " +
            "'X' means the reads and qualities should be trimmed at the clipped position; " +
            "'N' means the bases should be changed to Ns in the clipped region; and any " +
            "integer means that the base qualities should be set to that value in the " +
            "clipped region.", optional=true)
    public String CLIPPING_ACTION;


    public static void main(final String[] argv) {
        System.exit(new GCSamToFastq().instanceMain(argv));
    }

    private static FastqWriterFactory fastqWriterFactory;

    private static FastqWriterFactory FastqWriterFactoryInstance(){
      if(fastqWriterFactory == null){
        fastqWriterFactory = new FastqWriterFactory();
      }
      return fastqWriterFactory;
    }

    protected int doWork() {
        IoUtil.assertFileIsReadable(INPUT);
        
        if (OUTPUT_PER_RG) {
            doGrouped();
        } else {
            IoUtil.assertFileIsWritable(FASTQ);

            if (SECOND_END_FASTQ == null) {
                doUnpaired();
            }
            else {
                doPaired();
            }
        }
        return 0;
    }

    protected void doUnpaired() {

        final SAMFileReader reader = new SAMFileReader(IoUtil.openFileForReading(INPUT));
        final FastqWriter writer = FastqWriterFactoryInstance().newWriter(FASTQ);

        for (final SAMRecord record : reader ) {
            if (record.getReadFailsVendorQualityCheckFlag() && !INCLUDE_NON_PF_READS) {
                // do nothing
            }
            else {
                writeRecord(record, null, writer);
            }
        }
        reader.close();
        writer.close();
    }

    protected void notifyOrphan(String name) {
        if (IGNORE_ORPHAN_MATES == false)
            throw new PicardException("Read "+name+" is orphaned!");
    }

    protected void doPaired() {
        IoUtil.assertFileIsWritable(SECOND_END_FASTQ);
        IoUtil.assertFileIsWritable(FRAGMENT_FASTQ);

        final SAMFileReader reader = new SAMFileReader(IoUtil.openFileForReading(INPUT));
        final FastqWriter writer1 = FastqWriterFactoryInstance().newWriter(FASTQ);
        final FastqWriter writer2 = FastqWriterFactoryInstance().newWriter(SECOND_END_FASTQ);
        final FastqWriter fragWriter = FastqWriterFactoryInstance().newWriter(FRAGMENT_FASTQ);
        final Map<String,SAMRecord> firstSeenMates = new HashMap<String,SAMRecord>();
        final Set<String> failedReadNames = new HashSet<String>();

        try {

            for (final SAMRecord currentRecord : reader ) {

                final String currentReadName = currentRecord.getReadName() ;
                final SAMRecord firstRecord = firstSeenMates.get(currentReadName);

                // Skip non-PF reads as necessary
                if (currentRecord.getReadFailsVendorQualityCheckFlag() && !INCLUDE_NON_PF_READS) {
                    if (currentRecord.getReadPairedFlag()) {
                        failedReadNames.add(currentReadName);
                        // if this record failed QC, but we were already holding its mate...
                        if (firstRecord != null) {
                            firstSeenMates.remove(currentReadName);
                            notifyOrphan(currentReadName); 
                            writeRecord(firstRecord, null, fragWriter);
                        }
                    }
                    continue;
                }

                if (currentRecord.getReadPairedFlag()) {
                    // if this reads mate already failed QC...
                    if (failedReadNames.contains(currentReadName)) {
                        notifyOrphan(currentReadName); 
                        writeRecord(currentRecord, null, fragWriter);
                        continue;
                    }

                    if (firstRecord == null) {
                        firstSeenMates.put(currentReadName, currentRecord) ;
                    }
                    else {
                        assertPairedMates(firstRecord, currentRecord);

                        if (currentRecord.getFirstOfPairFlag()) {
                             writeRecord(currentRecord, 1, writer1);
                             writeRecord(firstRecord, 2, writer2);
                        }
                        else {
                             writeRecord(firstRecord, 1, writer1);
                             writeRecord(currentRecord, 2, writer2);
                        }
                        firstSeenMates.remove(currentReadName);
                    }
                } else {
                    writeRecord(currentRecord, null, fragWriter);
                }
            }

            if (firstSeenMates.size() > 0)  {
                
                // are we ignoring these.    
                if (IGNORE_ORPHAN_MATES == false)
                    throw new PicardException("Found "+firstSeenMates.size()+" reads with flags that indicated they were paired, but no mates were seen.");
            
                for (final SAMRecord currentRecord : firstSeenMates.values()) {
                    writeRecord(currentRecord, null, fragWriter);
                }

            }

        } finally {
            // Flush as much as possible.
            writer1.close();
            writer2.close();
            fragWriter.close();
            reader.close();
        }

    }

    protected void doGrouped()
    {
        final SAMFileReader reader = new SAMFileReader(IoUtil.openFileForReading(INPUT));
        final Map<String,SAMRecord> firstSeenMates = new HashMap<String,SAMRecord>();
        final Map<SAMReadGroupRecord, List<FastqWriter>> writers = new HashMap<SAMReadGroupRecord, List<FastqWriter>>();

        for (final SAMRecord currentRecord : reader ) {
            // Skip non-PF reads as necessary
            if (currentRecord.getReadFailsVendorQualityCheckFlag() && !INCLUDE_NON_PF_READS) continue;

            if(currentRecord.getReadPairedFlag())
            {
                doGroupedPaired(firstSeenMates, writers, currentRecord);
            }
            else
            {
                doGroupedUnpaired(writers, currentRecord);
            }
        }

        if (firstSeenMates.size() > 0 && IGNORE_ORPHAN_MATES == false) {
            throw new PicardException("Found "+firstSeenMates.size()+" unpaired mates");
        }

        reader.close();
        for(final List<FastqWriter> writerPair : writers.values()){
            for(final FastqWriter fq : writerPair){
                fq.close();
            }
        }
    }

    protected void doGroupedPaired(final Map<String,SAMRecord> firstSeenMates,
                                final Map<SAMReadGroupRecord, List<FastqWriter>> writers, final SAMRecord currentRecord) {
        final String currentReadName = currentRecord.getReadName() ;
        final SAMRecord firstRecord = firstSeenMates.remove(currentReadName);

        if (firstRecord == null) {
            firstSeenMates.put(currentReadName, currentRecord) ;
        }
        else {
            assertPairedMates(firstRecord, currentRecord);

            final SAMReadGroupRecord readGroup = currentRecord.getReadGroup();
            List<FastqWriter> writerPair;
            writerPair = writers.get(readGroup);
            if(writerPair == null)
            {
                final File fq1 = makeReadGroupFile(readGroup, "_1");
                IoUtil.assertFileIsWritable(fq1);
                final File fq2 = makeReadGroupFile(readGroup, "_2");
                IoUtil.assertFileIsWritable(fq2);

                writerPair = new ArrayList<FastqWriter>();
                writerPair.add(FastqWriterFactoryInstance().newWriter(fq1));
                writerPair.add(FastqWriterFactoryInstance().newWriter(fq2));
                writers.put(readGroup, writerPair);
            }

            if (currentRecord.getFirstOfPairFlag()) {
                 writeRecord(currentRecord, 1, writerPair.get(0));
                 writeRecord(firstRecord, 2, writerPair.get(1));
            }
            else {
                 writeRecord(firstRecord, 1, writerPair.get(0));
                 writeRecord(currentRecord, 2, writerPair.get(1));
            }
        }
    }

    protected void doGroupedUnpaired(final Map<SAMReadGroupRecord, List<FastqWriter>> writers, final SAMRecord currentRecord) {
        final SAMReadGroupRecord readGroup = currentRecord.getReadGroup();
        final SAMFileReader reader = new SAMFileReader(IoUtil.openFileForReading(INPUT));

        List<FastqWriter> writerList = writers.get(readGroup);
        if(writerList == null){
            final File fq1 = makeReadGroupFile(readGroup, null);
            IoUtil.assertFileIsWritable(fq1);

            writerList = new ArrayList<FastqWriter>();
            writerList.add(FastqWriterFactoryInstance().newWriter(fq1));
        }

        writeRecord(currentRecord, null, writerList.get(0));
        reader.close();
    }

    private File makeReadGroupFile(final SAMReadGroupRecord readGroup, final String preExtSuffix) {
        String fileName = readGroup.getPlatformUnit();
        if (fileName == null) fileName = readGroup.getReadGroupId();
        fileName = IoUtil.makeFileNameSafe(fileName);
        if(preExtSuffix != null) fileName += preExtSuffix;
        fileName += ".fastq";

        if(OUTPUT_DIR != null) return new File(OUTPUT_DIR, fileName);
        return new File(fileName);
    }

    void writeRecord(final SAMRecord read, final Integer mateNumber, final FastqWriter writer) {
        final String seqHeader = mateNumber==null ? read.getReadName() : read.getReadName() + "/"+ mateNumber;
        String readString = read.getReadString();
        String baseQualities = read.getBaseQualityString();

        // If we're clipping, do the right thing to the bases or qualities
        if (CLIPPING_ATTRIBUTE != null) {
            final Integer clipPoint = (Integer)read.getAttribute(CLIPPING_ATTRIBUTE);
            if (clipPoint != null) {
                if (CLIPPING_ACTION.equalsIgnoreCase("X")) {
                    readString = clip(readString, clipPoint, null,
                            !read.getReadNegativeStrandFlag());
                    baseQualities = clip(baseQualities, clipPoint, null,
                            !read.getReadNegativeStrandFlag());

                }
                else if (CLIPPING_ACTION.equalsIgnoreCase("N")) {
                    readString = clip(readString, clipPoint, 'N',
                            !read.getReadNegativeStrandFlag());
                }
                else {
                    final char newQual = SAMUtils.phredToFastq(
                            new byte[] { (byte)Integer.parseInt(CLIPPING_ACTION)}).charAt(0);
                    baseQualities = clip(baseQualities, clipPoint, newQual,
                            !read.getReadNegativeStrandFlag());
                }
            }
        }
        if ( RE_REVERSE && read.getReadNegativeStrandFlag() ) {
            readString = SequenceUtil.reverseComplement(readString);
            baseQualities = StringUtil.reverseString(baseQualities);
        }
        writer.write(new FastqRecord(seqHeader, readString, "", baseQualities));

    }

    /**
     * Utility method to handle the changes required to the base/quality strings by the clipping
     * parameters.
     *
     * @param src           The string to clip
     * @param point         The 1-based position of the first clipped base in the read
     * @param replacement   If non-null, the character to replace in the clipped positions
     *                      in the string (a quality score or 'N').  If null, just trim src
     * @param posStrand     Whether the read is on the positive strand
     * @return String       The clipped read or qualities
     */
    private String clip(final String src, final int point, final Character replacement, final boolean posStrand) {
        final int len = src.length();
        String result = posStrand ? src.substring(0, point-1) : src.substring(len-point+1);
        if (replacement != null) {
            if (posStrand) {
                for (int i = point; i <= len; i++ ) {
                    result += replacement;
                }
            }
            else {
                for (int i = 0; i <= len-point; i++) {
                    result = replacement + result;
                }
            }
        }
        return result;
    }

    private void assertPairedMates(final SAMRecord record1, final SAMRecord record2) {
        if (! (record1.getFirstOfPairFlag() && record2.getSecondOfPairFlag() ||
               record2.getFirstOfPairFlag() && record1.getSecondOfPairFlag() ) ) {
            throw new PicardException("Illegal mate state: " + record1.getReadName());
        }
    }


    /**
    * Put any custom command-line validation in an override of this method.
    * clp is initialized at this point and can be used to print usage and access argv.
     * Any options set by command-line parser can be validated.
    * @return null if command line is valid.  If command line is invalid, returns an array of error
    * messages to be written to the appropriate place.
    */
    protected String[] customCommandLineValidation() {
        if ((CLIPPING_ATTRIBUTE != null && CLIPPING_ACTION == null) ||
            (CLIPPING_ATTRIBUTE == null && CLIPPING_ACTION != null)) {
            return new String[] {
                    "Both or neither of CLIPPING_ATTRIBUTE and CLIPPING_ACTION should be set." };
        }
        if (CLIPPING_ACTION != null) {
            if (CLIPPING_ACTION.equals("N") || CLIPPING_ACTION.equals("X")) {
                // Do nothing, this is fine
            }
            else {
                try {
                    Integer.parseInt(CLIPPING_ACTION);
                }
                catch (NumberFormatException nfe) {
                    return new String[] {"CLIPPING ACTION must be one of: N, X, or an integer"};
                }
            }
        }

        return null;
    }
}
