//
//  UnzipTask.c
//  Notification
//
//  Created by spr on 2021/3/2.
//

#include "UnzipTask.h"


@implementation UnzipTask
//    //TODO 考虑使用线程池
//    private String zipFilePath;
//    private long zipFileSize = 0;
//    private long totalUnzipFileSize = 0;
//    private long totalFileCountInZip = 0;
//    private long unzipedFileSize = 0;
//    private String unzipFileDirPath;
//    private ProcessHandler unZipHandler;
//    private String errorMsg;
//    private int errorCode = -1;
//    private long lastUnzipedSize = 0;
//
//    public UnzipTask(String zipFilePath, String unzipFileDirPath, ProcessHandler unZipHandler) {
//        init(zipFilePath, unzipFileDirPath, unZipHandler);
//    }
//
//    private void init(String zipFilePath, String unzipFileDirPath, ProcessHandler unZipHandler) {
//        this.zipFilePath = zipFilePath;
//        this.unzipFileDirPath = unzipFileDirPath;
//        this.unZipHandler = unZipHandler;
//        stopFlag = false;
//        retrieveZipInfos();
//    }
//
//    public void retrieveZipInfos() {
////            file list entry{name, path ,size}
//        File file = new File(zipFilePath);
//        if (!file.exists()) {
//            Log.e(TAG, String.format("the zip file of %s not exists!", zipFilePath));
//            return;
//        }
//        try {
//            zipFileSize = file.length();
//            ZipFile zipFile = new ZipFile(file);
//            totalFileCountInZip = zipFile.size();
//            Enumeration<?> entries = zipFile.entries();
//            List<ZipEntry> entryList = new ArrayList<ZipEntry>();
//            while (entries.hasMoreElements() && !stopFlag) {
//                ZipEntry entry = (ZipEntry) entries.nextElement();
//                if (entry.isDirectory()) continue;
//                entryList.add(entry);
//                totalUnzipFileSize += entry.getSize();
//            }
//            zipFile.close();
//        } catch (Exception e) {
//            Log.d(TAG, "retrieveZipInfos failure!");
//        }
//    }
//
//    public void startProcess() {
//        File file = new File(zipFilePath);
//        if (!file.exists()) {
//            Log.e(TAG, String.format("the zip file of %s not exists!", zipFilePath));
//            complete();
////                TODO callback
//            return;
//        }
//        InputStream inputStream = null;
//        ZipFile zipFile = null;
//        try {
//            zipFile = new ZipFile(file);
//            totalFileCountInZip = zipFile.size();
//            Enumeration<?> entries = zipFile.entries();
//            unzipStart();
//            while (entries.hasMoreElements() && !stopFlag) {
//                ZipEntry zipEntry = (ZipEntry) entries.nextElement();
//                if (zipEntry.isDirectory()) continue;
//                File destFile = prepareUnzipFilePath(zipEntry);
//                inputStream = zipFile.getInputStream(zipEntry);
//                if (null == inputStream) {
//                    Log.d(TAG, String.format("\n unzip failure stream is null for %s", destFile));
//                } else {
//                    boolean unzipRet = writeFile(inputStream, destFile);
//                    if (!unzipRet) {
//                        Log.d(TAG, "unzip result falure! msg:" + errorMsg);
//                    }
//                    unzipedFileSize += zipEntry.getSize();
//                }
//            }
//        } catch (IOException e) {
//            e.printStackTrace();
//            errorMsg = e.getMessage();
//            errorCode = 3;
//        } finally {
//            try {
//                if (null != inputStream) {
//                    inputStream.close();
//                }
//                if (null != zipFile) {
//                    zipFile.close();
//                }
//            } catch (IOException e) {
//                e.printStackTrace();
//                errorMsg = e.getMessage();
//                errorCode = 3;
//            }
//
//            if (null == errorMsg && unzipedFileSize != totalUnzipFileSize) {
//                errorCode = 4;
//            }
//
//            if (null != errorMsg || unzipedFileSize != totalUnzipFileSize) {
//                errorMsg = String.format("unzip terminate or %s!", errorMsg);
//                unzipFailure();
//            } else {
//                complete();
//            }
//        }
//    }
//
//    private File prepareUnzipFilePath(ZipEntry zipEntry) {
//        String entryName = zipEntry.getName();
//        File destFile = new File(unzipFileDirPath, entryName);
//        if (!destFile.getParentFile().exists()) {
//            destFile.getParentFile().mkdirs();
//        }
//        if (destFile.exists()) destFile.delete();
//        return destFile;
//    }
//
//    private boolean writeFile(InputStream inputStream, File destFile) {
//        BufferedInputStream bis = null;
//        FileOutputStream fos = null;
//        BufferedOutputStream bos = null;
//        try {
//            bis = new BufferedInputStream(inputStream);
//            fos = new FileOutputStream(destFile, true);
//            bos = new BufferedOutputStream(fos);
//            byte[] buffer = new byte[8 * 1024];
//            int len = bis.read(buffer);
//            while (len > 0 && !stopFlag) {
//                bos.write(buffer, 0, len);
//                progress();
//                len = bis.read(buffer);
//            }
//        } catch (IOException e) {
//            e.printStackTrace();
//            errorMsg = e.getMessage();
//            errorCode = 3;
//        } finally {
//            tryCloseFileStream(bis, fos, bos);
//        }
//        if (null != errorMsg) {
//            return false;
//        } else {
//            return true;
//        }
//    }
//
//    public long getProcessSpeed(long deltaTime) {
//        long speed = (unzipedFileSize - lastUnzipedSize) * 1000 / deltaTime;
//        lastUnzipedSize = unzipedFileSize;
//        return speed;
//    }
//
//    private void tryCloseFileStream(BufferedInputStream bis, FileOutputStream fos, BufferedOutputStream bos) {
//        try {
//            if (null != bos) {
//                bos.close();
//            }
//        } catch (Exception e) {
//            Log.e(TAG, "tryCloseFileStream Exception:" + e.toString());
//        }
//        try {
//            if (null != fos) {
//                fos.close();
//            }
//        } catch (Exception e) {
//            Log.e(TAG, "tryCloseFileStream Exception:" + e.toString());
//        }
//        try {
//            if (null != bis) {
//                bis.close();
//            }
//        } catch (Exception e) {
//            Log.e(TAG, "tryCloseFileStream Exception:" + e.toString());
//        }
//    }
//
//    public int getPercent() {
//        double percent = unzipedFileSize * 100 / (totalUnzipFileSize);
//        int result = (int) Math.floor(percent);
//        return result;
//    }
//
//    public int getRetryCount() {
//        return retryCount;
//    }
//
//    private void progress() {
//        unZipHandler.progress(this);
//    }
//
//    private void complete() {
//        FileUtil.deleteFile(zipFilePath);
//        unZipHandler.complete(this);
//    }
//
//    private void unzipStart() {
//        unZipHandler.handleStart(this);
//    }
//
//    private void unzipFailure() {
//        unZipHandler.failure(this, errorCode, errorMsg, errorCode);
//    }
@end
